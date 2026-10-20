#!/usr/bin/env Rscript
# brewery-des-demo: read the Obsidian vault, simulate the brewery, write results back.
#
#   Rscript R/run.R                    # run every scenario note, then the comparison
#   Rscript R/run.R Baseline "Second filler"
#   Rscript R/run.R --check            # validate the vault only
#   Rscript R/run.R --compare          # rebuild Results/Comparison.md from saved results
#   Rscript R/run.R --reps 10 Baseline # fewer replications (default 40)
#
# All plant data is synthetic. See README.md.

local_lib <- path.expand("~/Rlibs/brewery-des")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
suppressPackageStartupMessages({
  library(simmer)
  library(simmer.plot)
  library(yaml)
  library(ggplot2)
  library(parallel)
})

# ---------------------------------------------------------------------------
# Paths and arguments
# ---------------------------------------------------------------------------
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
ROOT  <- normalizePath(file.path(dirname(script_path), ".."))
VAULT <- file.path(ROOT, "vault")
RES   <- file.path(VAULT, "Results")
IMG   <- file.path(RES, "img")
DATA  <- file.path(RES, "data")

args <- commandArgs(TRUE)
opt_check   <- "--check" %in% args
opt_compare <- "--compare" %in% args
n_reps <- 40L
if ("--reps" %in% args) {
  i <- which(args == "--reps")
  n_reps <- as.integer(args[i + 1])
  args <- args[-c(i, i + 1)]
}
scen_args <- setdiff(args, c("--check", "--compare"))

# ---------------------------------------------------------------------------
# Reading notes
# ---------------------------------------------------------------------------
note_error <- function(note, msg) {
  stop(sprintf("In note '%s': %s", note, msg), call. = FALSE)
}

read_note <- function(path) {
  name  <- sub("\\.md$", "", basename(path))
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (length(lines) == 0 || trimws(lines[1]) != "---")
    return(list(name = name, path = path, fm = list(), body = lines))
  ends <- which(trimws(lines) == "---")
  if (length(ends) < 2) note_error(name, "front matter opens with --- but never closes")
  end <- ends[2]
  txt <- if (end > 2) paste(lines[2:(end - 1)], collapse = "\n") else ""
  fm <- tryCatch(yaml.load(txt),
                 error = function(e) note_error(name, paste("the properties block is not valid YAML:", conditionMessage(e))))
  if (is.null(fm)) fm <- list()
  list(name = name, path = path, fm = fm,
       body = if (end < length(lines)) lines[(end + 1):length(lines)] else character())
}

load_vault <- function() {
  files <- list.files(VAULT, pattern = "\\.md$", recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("/(Results|Templates|\\.obsidian)/", files)]
  notes <- lapply(files, read_note)
  nm <- vapply(notes, `[[`, "", "name")
  dup <- unique(nm[duplicated(nm)])
  if (length(dup)) stop(sprintf("Two notes share the name '%s'; note names must be unique.", dup[1]), call. = FALSE)
  setNames(notes, nm)
}

link_target <- function(x) {
  # "[[Bright tanks]]", "[[Bright tanks|alias]]" or "[[Bright tanks#Heading]]" -> "Bright tanks"
  if (is.null(x) || !is.character(x) || length(x) != 1) return(NA_character_)
  m <- regmatches(x, regexec("^\\s*\\[\\[([^]|#]+)(#[^]|]*)?(\\|[^]]*)?\\]\\]\\s*$", x))[[1]]
  if (length(m) == 0) NA_character_ else trimws(m[2])
}

# ---------------------------------------------------------------------------
# Scenario overrides: "Note name.field.subfield": value
# ---------------------------------------------------------------------------
apply_overrides <- function(notes, scen) {
  ov <- scen$fm$overrides
  if (is.null(ov) || length(ov) == 0) return(notes)
  if (!is.list(ov) || is.null(names(ov)))
    note_error(scen$name, "overrides must be a map of \"Note name.property\": value")
  for (key in names(ov)) {
    dot <- regexpr(".", key, fixed = TRUE)
    if (dot < 0) note_error(scen$name, sprintf("override '%s' should look like 'Note name.property'", key))
    target <- substr(key, 1, dot - 1)
    path   <- strsplit(substr(key, dot + 1, nchar(key)), ".", fixed = TRUE)[[1]]
    if (is.null(notes[[target]]))
      note_error(scen$name, sprintf("override '%s' names note '%s', which does not exist", key, target))
    cur <- notes[[target]]$fm
    for (p in path) {
      if (!is.list(cur) || is.null(cur[[p]]))
        note_error(scen$name, sprintf("override '%s': note '%s' has no property '%s'", key, target, paste(path, collapse = ".")))
      cur <- cur[[p]]
    }
    notes[[target]]$fm[[path]] <- ov[[key]]
  }
  notes
}

# ---------------------------------------------------------------------------
# Quantities and distributions (everything converted to hours)
# ---------------------------------------------------------------------------
TIME_UNITS <- c(min = 1 / 60, h = 1, d = 24)
DISTS <- list(fixed = "value", uniform = c("min", "max"), triangular = c("min", "mode", "max"),
              normal = c("mean", "sd"), lognormal = c("mean", "sd"), exponential = "mean")

time_qty <- function(x, note, field) {
  if (!is.list(x) || is.null(x$value) || is.null(x$unit))
    note_error(note, sprintf("'%s' needs a value and a unit (one of %s)", field, paste(names(TIME_UNITS), collapse = ", ")))
  if (!x$unit %in% names(TIME_UNITS))
    note_error(note, sprintf("'%s' has unit '%s'; use one of %s", field, x$unit, paste(names(TIME_UNITS), collapse = ", ")))
  if (!is.numeric(x$value) || x$value < 0) note_error(note, sprintf("'%s' value must be a non-negative number", field))
  x$value * TIME_UNITS[[x$unit]]
}

make_dist <- function(d, note, field) {
  if (!is.list(d) || is.null(d$dist))
    note_error(note, sprintf("'%s' must be a distribution with dist: and unit: (dist one of %s)", field, paste(names(DISTS), collapse = ", ")))
  if (!d$dist %in% names(DISTS))
    note_error(note, sprintf("'%s' uses unknown distribution '%s'; use one of %s", field, d$dist, paste(names(DISTS), collapse = ", ")))
  if (is.null(d$unit) || !d$unit %in% names(TIME_UNITS))
    note_error(note, sprintf("'%s' needs unit: one of %s (got '%s')", field, paste(names(TIME_UNITS), collapse = ", "), format(d$unit)))
  need <- DISTS[[d$dist]]
  miss <- need[vapply(need, function(p) is.null(d[[p]]) || !is.numeric(d[[p]]), TRUE)]
  if (length(miss)) note_error(note, sprintf("'%s' (%s) is missing numeric %s", field, d$dist, paste(miss, collapse = ", ")))
  k <- TIME_UNITS[[d$unit]]
  p <- lapply(d[need], function(v) v * k)
  f <- switch(d$dist,
    fixed       = function() p$value,
    uniform     = function() runif(1, p$min, p$max),
    triangular  = {
      if (!(p$min <= p$mode && p$mode <= p$max)) note_error(note, sprintf("'%s': triangular needs min <= mode <= max", field))
      function() {
        u <- runif(1); a <- p$min; b <- p$max; c <- p$mode
        if (b == a) return(a)
        if (u < (c - a) / (b - a)) a + sqrt(u * (b - a) * (c - a)) else b - sqrt((1 - u) * (b - a) * (b - c))
      }
    },
    normal      = function() max(0, rnorm(1, p$mean, p$sd)),
    lognormal   = {
      if (p$mean <= 0) note_error(note, sprintf("'%s': lognormal mean must be positive", field))
      s2 <- log(1 + (p$sd / p$mean)^2); ml <- log(p$mean) - s2 / 2
      function() rlnorm(1, ml, sqrt(s2))
    },
    exponential = function() rexp(1, 1 / p$mean))
  mean_h <- switch(d$dist, fixed = p$value, uniform = (p$min + p$max) / 2,
                   triangular = (p$min + p$mode + p$max) / 3, normal = p$mean,
                   lognormal = p$mean, exponential = p$mean)
  structure(f, mean_h = mean_h)
}

pos_int <- function(x, note, field) {
  if (is.null(x) || !is.numeric(x) || length(x) != 1 || x < 1 || x != round(x))
    note_error(note, sprintf("'%s' must be a whole number of at least 1 (got '%s')", field, format(x)))
  as.integer(x)
}
num <- function(x, note, field, lo = -Inf, hi = Inf) {
  if (is.null(x) || !is.numeric(x) || length(x) != 1 || x < lo || x > hi)
    note_error(note, sprintf("'%s' must be a number between %s and %s (got '%s')", field, lo, hi, format(x)))
  x
}

# ---------------------------------------------------------------------------
# Validate the vault and build a plain parameter list
# ---------------------------------------------------------------------------
ROUTE_ROLES <- c("brewhouse", "fermentation", "bright", "filler", "labeller", "palletiser", "warehouse", "dispatch")
DAYS <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

build_params <- function(notes) {
  types <- vapply(notes, function(n) as.character(n$fm$type %||% ""), "")
  stations <- notes[types == "station"]
  rules <- notes[types == "rule"]
  if (!length(stations)) stop("No notes with type: station found in the vault.", call. = FALSE)

  # --- routing via next: links
  for (s in stations) {
    if (is.null(s$fm$role) || !s$fm$role %in% ROUTE_ROLES)
      note_error(s$name, sprintf("role must be one of %s", paste(ROUTE_ROLES, collapse = ", ")))
    if (!is.null(s$fm$`next`)) {
      tgt <- link_target(s$fm$`next`)
      if (is.na(tgt)) note_error(s$name, sprintf("next: should be a link like \"[[Fermenters]]\" (got '%s')", s$fm$`next`))
      if (is.null(notes[[tgt]])) note_error(s$name, sprintf("next: links to [[%s]], but there is no note called '%s'", tgt, tgt))
      if (!identical(notes[[tgt]]$fm$type, "station")) note_error(s$name, sprintf("next: links to [[%s]], which is not a station (type: station)", tgt))
    }
  }
  starts <- names(stations)[vapply(stations, function(s) isTRUE(s$fm$start), TRUE)]
  if (length(starts) != 1) stop(sprintf("Exactly one station needs start: true (found %d: %s).", length(starts), paste(starts, collapse = ", ")), call. = FALSE)
  route <- starts
  repeat {
    nx <- link_target(stations[[tail(route, 1)]]$fm$`next`)
    if (is.na(nx)) break
    if (nx %in% route) note_error(tail(route, 1), sprintf("next: [[%s]] makes a loop in the routing", nx))
    route <- c(route, nx)
  }
  orphan <- setdiff(names(stations), route)
  if (length(orphan)) note_error(orphan[1], "this station is not reachable by following next: links from the start station")
  roles <- vapply(route, function(r) stations[[r]]$fm$role, "")
  if (!identical(unname(roles), ROUTE_ROLES))
    stop(sprintf("The routing is %s, but this model supports exactly the order %s. (Roles in route: %s)",
                 paste(route, collapse = " -> "), paste(ROUTE_ROLES, collapse = " -> "), paste(roles, collapse = ", ")), call. = FALSE)
  st <- setNames(lapply(route, function(r) stations[[r]]), roles)

  rule <- function(kind) {
    hit <- Filter(function(n) identical(n$fm$rule, kind), rules)
    if (length(hit) != 1) stop(sprintf("Need exactly one note with type: rule and rule: %s (found %d).", kind, length(hit)), call. = FALSE)
    hit[[1]]
  }
  r_shift <- rule("shifts"); r_co <- rule("changeovers"); r_stop <- rule("stoppages")
  r_dem <- rule("demand"); r_prod <- rule("products")

  # --- shift calendars
  cals <- r_shift$fm$calendars
  if (!is.list(cals) || !length(cals)) note_error(r_shift$name, "needs calendars:")
  hm <- function(x, field) {
    if (!is.character(x) || !grepl("^[0-9]{1,2}:00$", x)) note_error(r_shift$name, sprintf("'%s' must be a whole hour like \"06:00\" (got '%s')", field, format(x)))
    as.integer(sub(":00$", "", x))
  }
  calendars <- lapply(names(cals), function(cn) {
    c1 <- cals[[cn]]
    bad <- setdiff(c1$days, DAYS)
    if (length(bad)) note_error(r_shift$name, sprintf("calendar '%s' has unknown day '%s'; use %s", cn, bad[1], paste(DAYS, collapse = ", ")))
    s <- hm(c1$start, paste0(cn, ".start")); e <- hm(c1$end, paste0(cn, ".end"))
    if (e <= s) note_error(r_shift$name, sprintf("calendar '%s' ends before it starts", cn))
    list(days = match(c1$days, DAYS), start = s, end = e)
  })
  names(calendars) <- names(cals)
  for (s in st) if (is.null(s$fm$shift) || !s$fm$shift %in% names(calendars))
    note_error(s$name, sprintf("shift: '%s' is not a calendar in the Shifts note (%s)", format(s$fm$shift), paste(names(calendars), collapse = ", ")))

  # --- planned stoppages
  planned <- lapply(r_stop$fm$planned %||% list(), function(p) {
    cl <- unlist(p$calendar)
    bad <- setdiff(cl, names(calendars))
    if (length(bad)) note_error(r_stop$name, sprintf("stoppage '%s' names unknown calendar '%s'", p$name, bad[1]))
    days <- match(unlist(p$days %||% p$day), DAYS)
    if (anyNA(days) || !length(days)) note_error(r_stop$name, sprintf("stoppage '%s' needs day: or days: from %s", p$name, paste(DAYS, collapse = ", ")))
    start <- if (is.null(p$start)) 0L else hm(p$start, paste(p$name, "start"))
    dur <- if (is.null(p$duration)) 24 * 1 else time_qty(p$duration, r_stop$name, paste(p$name, "duration"))
    if (is.null(p$every_weeks) && is.null(p$weeks)) note_error(r_stop$name, sprintf("stoppage '%s' needs every_weeks: or weeks:", p$name))
    list(name = p$name, calendars = cl, days = days, start = start, dur = dur,
         every = p$every_weeks, weeks = unlist(p$weeks))
  })

  # --- products
  skus <- r_prod$fm$skus
  if (!is.list(skus) || !length(skus)) note_error(r_prod$name, "needs skus:")
  prod <- do.call(rbind, lapply(skus, function(k) {
    for (f in c("name", "format", "container_ml", "containers_per_case", "cases_per_pallet", "share"))
      if (is.null(k[[f]])) note_error(r_prod$name, sprintf("product '%s' is missing %s", format(k$name), f))
    data.frame(name = k$name, code = k$code %||% k$name, format = k$format,
               container_ml = k$container_ml, hl_per_pallet = k$container_ml * k$containers_per_case * k$cases_per_pallet / 1e5,
               share = k$share, stringsAsFactors = FALSE)
  }))
  if (abs(sum(prod$share) - 1) > 1e-6) note_error(r_prod$name, sprintf("product shares add up to %.3f, not 1", sum(prod$share)))

  # --- stations
  bh <- st$brewhouse; fv <- st$fermentation; bt <- st$bright
  fl <- st$filler; lb <- st$labeller; pl <- st$palletiser; wh <- st$warehouse; dp <- st$dispatch

  speed <- function(s, field = "line_speed") {
    ls <- s$fm[[field]]
    out <- sapply(unique(prod$format), function(fmt) {
      x <- ls[[fmt]]
      if (is.null(x)) note_error(s$name, sprintf("%s has no entry for format '%s' used in Products", field, fmt))
      if (!identical(x$unit, "containers/h")) note_error(s$name, sprintf("%s.%s unit must be containers/h (got '%s')", field, fmt, format(x$unit)))
      num(x$value, s$name, paste0(field, ".", fmt), 1)
    })
    out
  }
  failure <- function(s) {
    f <- s$fm$failure
    if (is.null(f)) return(NULL)
    list(mtbf = time_qty(f$mtbf, s$name, "failure.mtbf"), mttr = make_dist(f$mttr, s$name, "failure.mttr"))
  }
  tank <- num(fv$fm$tank_size_hl, fv$name, "tank_size_hl", 1)
  brew <- num(bh$fm$brew_length_hl, bh$name, "brew_length_hl", 1)
  if (abs(tank / brew - round(tank / brew)) > 1e-9)
    note_error(fv$name, sprintf("tank_size_hl (%s) must be a whole number of brews of %s hL (Brewhouse brew_length_hl)", tank, brew))
  if (num(bt$fm$tank_size_hl, bt$name, "tank_size_hl", 1) < tank * (1 - (fv$fm$loss_pct %||% 0) / 100))
    note_error(bt$name, "tank_size_hl is smaller than one fermenter's worth of beer")
  if (!identical(pl$fm$line_speed$unit, "pallets/h")) note_error(pl$name, sprintf("line_speed unit must be pallets/h (got '%s')", format(pl$fm$line_speed$unit)))

  dem <- r_dem$fm
  seas <- rep(1, 52)
  for (s in dem$seasonality %||% list()) {
    w <- as.integer(strsplit(as.character(s$weeks), "-")[[1]])
    if (length(w) == 1) w <- c(w, w)
    if (anyNA(w) || w[1] < 1 || w[2] > 52 || w[1] > w[2]) note_error(r_dem$name, sprintf("seasonality weeks '%s' should look like \"22-35\" within 1-52", s$weeks))
    seas[w[1]:w[2]] <- num(s$factor, r_dem$name, "seasonality factor", 0)
  }
  odays <- match(unlist(dem$order_days), DAYS)
  if (anyNA(odays) || !length(odays)) note_error(r_dem$name, "order_days must be days from Mon..Sun")

  list(
    route = route, names = setNames(route, ROUTE_ROLES), calendars = calendars, planned = planned, prod = prod,
    brewhouse = list(cap = pos_int(bh$fm$capacity, bh$name, "capacity"), brew_hl = brew, brews = round(tank / brew),
                     t = make_dist(bh$fm$process_time, bh$name, "process_time"), shift = bh$fm$shift, failure = failure(bh)),
    fv = list(cap = pos_int(fv$fm$capacity, fv$name, "capacity"), tank_hl = tank,
              t = make_dist(fv$fm$process_time, fv$name, "process_time"), cip = make_dist(fv$fm$cip, fv$name, "cip"),
              loss = num(fv$fm$loss_pct %||% 0, fv$name, "loss_pct", 0, 100) / 100),
    bt = list(cap = pos_int(bt$fm$capacity, bt$name, "capacity"), transfer = make_dist(bt$fm$transfer_time, bt$name, "transfer_time"),
              hold = make_dist(bt$fm$process_time, bt$name, "process_time"), cip = make_dist(bt$fm$cip, bt$name, "cip")),
    filler = list(cap = pos_int(fl$fm$capacity, fl$name, "capacity"), speed = speed(fl),
                  eff = num(fl$fm$efficiency_pct %||% 100, fl$name, "efficiency_pct", 1, 100) / 100,
                  loss = num(fl$fm$loss_pct %||% 0, fl$name, "loss_pct", 0, 100) / 100, shift = fl$fm$shift, failure = failure(fl)),
    labeller = list(cap = pos_int(lb$fm$capacity, lb$name, "capacity"), speed = speed(lb), shift = lb$fm$shift, failure = failure(lb)),
    palletiser = list(cap = pos_int(pl$fm$capacity, pl$name, "capacity"), speed = num(pl$fm$line_speed$value, pl$name, "line_speed", 1),
                      shift = pl$fm$shift, failure = failure(pl)),
    warehouse = list(cap = pos_int(wh$fm$capacity, wh$name, "capacity")),
    dispatch = list(cap = pos_int(dp$fm$capacity, dp$name, "capacity"), per_truck = pos_int(dp$fm$pallets_per_truck, dp$name, "pallets_per_truck"),
                    t = make_dist(dp$fm$process_time, dp$name, "process_time"), shift = dp$fm$shift),
    co = list(format = make_dist(r_co$fm$format_change, r_co$name, "format_change"),
              product = make_dist(r_co$fm$product_change, r_co$name, "product_change")),
    demand = list(base = num(dem$base_hl_per_week, r_dem$name, "base_hl_per_week", 0), seas = seas,
                  cv = num(dem$noise_cv %||% 0, r_dem$name, "noise_cv", 0, 2), odays = odays,
                  otime = hm(dem$order_time %||% "06:00", "order_time"),
                  cover = num(dem$planning$cover_weeks, r_dem$name, "planning.cover_weeks", 0),
                  init = num(dem$planning$initial_stock_weeks %||% 0, r_dem$name, "planning.initial_stock_weeks", 0),
                  warmup = pos_int(dem$warmup_weeks %||% 6, r_dem$name, "warmup_weeks"))
  )
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Calendars -> capacity schedules
# ---------------------------------------------------------------------------
cal_week <- function(sim_week, warmup) ((sim_week - warmup - 1) %% 52) + 1  # sim week 1.. -> calendar week 1..52

availability <- function(P, cal_name, weeks) {
  H <- weeks * 168
  h <- 0:(H - 1)
  day <- (h %/% 24) %% 7 + 1; hod <- h %% 24
  c1 <- P$calendars[[cal_name]]
  a <- as.integer(day %in% c1$days & hod >= c1$start & hod < c1$end)
  wk <- cal_week(h %/% 168 + 1, P$demand$warmup)
  for (p in P$planned) if (cal_name %in% p$calendars) {
    hit_w <- if (!is.null(p$every)) ((wk - 1) %% p$every) == 0 else wk %in% p$weeks
    from <- p$start; to <- p$start + p$dur
    a[hit_w & day %in% p$days & hod >= from & hod < to] <- 0L
  }
  a
}

to_schedule <- function(avail, cap) {
  r <- rle(avail * cap)
  times <- c(0, cumsum(r$lengths))[seq_along(r$values)]
  schedule(times, r$values, period = Inf)
}

# ---------------------------------------------------------------------------
# One replication
# ---------------------------------------------------------------------------
run_rep <- function(P, rep, seed) {
  set.seed(seed)
  W <- P$demand$warmup; weeks <- W + 52
  t0 <- W * 168; t1 <- weeks * 168
  prod <- P$prod; nsku <- nrow(prod)

  # line rates (hL/h at rated speed, before efficiency) per format
  hl <- function(cph, ml) cph * ml / 1e5
  line_rate <- function(k) {
    f <- prod$format[k]; ml <- prod$container_ml[k]
    min(hl(P$filler$speed[[f]], ml), hl(P$labeller$speed[[f]], ml), P$palletiser$speed * prod$hl_per_pallet[k]) * P$filler$eff
  }
  rate_k <- vapply(seq_len(nsku), line_rate, 0)
  hl_bright <- P$fv$tank_hl * (1 - P$fv$loss)
  hl_pack <- hl_bright * (1 - P$filler$loss)

  # demand: expected weekly hL by sim week, and the order book
  week_mean <- P$demand$base * P$demand$seas[cal_week(1:weeks, W)]
  week_real <- week_mean * pmax(0, 1 + P$demand$cv * rnorm(weeks))
  od <- P$demand$odays
  orders <- expand.grid(day = od, week = 1:weeks)
  orders$t <- (orders$week - 1) * 168 + (orders$day - 1) * 24 + P$demand$otime
  qty <- sapply(seq_len(nsku), function(k) {
    x <- week_real[orders$week] * prod$share[k] / prod$hl_per_pallet[k] / length(od)
    floor(x + runif(length(x)))
  })
  qty <- matrix(qty, ncol = nsku)
  # expected hL per hour for the plan's forecast; runs past the end of the simulation so the plan
  # does not wind down in the last weeks (the calendar simply wraps into next year)
  ext <- weeks + ceiling(P$demand$cover) + 1
  hourly_mean <- rep(P$demand$base * P$demand$seas[cal_week(1:ext, W)] / 168, each = 168)

  # state shared with trajectory callbacks
  S <- new.env()
  S$stock <- floor(P$demand$init * week_mean[1] * prod$share / prod$hl_per_pallet)
  S$wip_hl <- rep(0, nsku); S$backlog <- rep(0, nsku)
  S$queue_sku <- integer(); S$pre_brew <- 0L; S$order_i <- 0L; S$to_load <- 0
  S$last_sku <- rep(NA_integer_, P$filler$cap)
  S$ordered <- rep(0, nsku); S$ontime <- rep(0, nsku); S$late <- rep(0, nsku)
  S$rec <- new.env()
  S$fail <- list(); S$plan <- integer(4); names(S$plan) <- c("brewing", "no_need", "tanks_full", "other")
  S$weekly <- matrix(NA_real_, weeks, 3 + 2 * nsku)
  S$co_h <- 0
  in_win <- function(t) t >= t0 && t < t1

  env <- simmer(paste0("rep", rep))
  rec <- function(trj, field) trj %>% timeout(function() {
    nm <- get_name(env); x <- S$rec[[nm]]; if (is.null(x)) x <- list()
    x[[field]] <- now(env); assign(nm, x, envir = S$rec); 0
  })

  # shipped pallets accumulate until a full truck; each truck is a clone that occupies a loading bay
  load_trucks <- function(n) {
    S$to_load <- S$to_load + n
    nt <- S$to_load %/% P$dispatch$per_truck
    S$to_load <- S$to_load - nt * P$dispatch$per_truck
    nt
  }
  send_trucks <- function(trj) trj %>%
    branch(function() as.integer(get_attribute(env, "trucks") > 0), continue = FALSE,
           trajectory() %>% clone(n = function() get_attribute(env, "trucks")) %>%
             seize("Dispatch") %>% timeout(function() P$dispatch$t()) %>% release("Dispatch"))

  fillers <- paste0("Filler_", seq_len(P$filler$cap))
  labs <- paste0("Labeller_", seq_len(P$labeller$cap))
  pals <- paste0("Palletiser_", seq_len(P$palletiser$cap))
  line_of <- function(res) as.integer(sub(".*_", "", res))

  batch <- trajectory("batch") %>%
    set_attribute("sku", function() { k <- S$queue_sku[1]; S$queue_sku <- S$queue_sku[-1]; k }) %>%
    seize("Fermenters") %>% rec("fv_got") %>%
    timeout(function() P$fv$cip()) %>%
    rec("bh_req") %>% seize("Brewhouse") %>% rec("bh_got") %>%
    timeout(function() { S$pre_brew <- S$pre_brew - 1L; sum(replicate(P$brewhouse$brews, P$brewhouse$t())) }) %>%
    release("Brewhouse") %>%
    timeout(function() P$fv$t()) %>% rec("ferm_done") %>%
    seize("Bright tanks") %>% rec("bt_got") %>%
    timeout(function() P$bt$cip() + P$bt$transfer()) %>%
    release("Fermenters") %>% rec("fv_rel") %>%
    timeout(function() P$bt$hold()) %>% rec("ready") %>%
    select(fillers, policy = "shortest-queue", id = 0) %>% seize_selected(id = 0) %>%
    set_attribute("line", function() line_of(get_selected(env, 0))) %>%
    select(function() labs[(line_of(get_selected(env, 0)) - 1) %% length(labs) + 1], id = 1) %>% seize_selected(id = 1) %>%
    select(function() pals[(line_of(get_selected(env, 0)) - 1) %% length(pals) + 1], id = 2) %>% seize_selected(id = 2) %>%
    rec("line_got") %>%
    timeout(function() {
      i <- get_attribute(env, "line"); k <- get_attribute(env, "sku"); last <- S$last_sku[i]
      S$last_sku[i] <- k
      co <- if (is.na(last) || last == k) 0 else if (prod$format[last] != prod$format[k]) P$co$format() else P$co$product()
      if (in_win(now(env))) S$co_h <- S$co_h + co
      co
    }) %>%
    timeout(function() hl_bright / rate_k[get_attribute(env, "sku")]) %>%
    release_selected(id = 2) %>% release_selected(id = 1) %>% release_selected(id = 0) %>%
    release("Bright tanks") %>% rec("packed") %>%
    set_attribute("trucks", function() {
      k <- get_attribute(env, "sku")
      pal <- floor(hl_pack / prod$hl_per_pallet[k])
      S$wip_hl[k] <- S$wip_hl[k] - hl_pack
      fill <- min(S$backlog[k], pal)
      S$backlog[k] <- S$backlog[k] - fill
      if (in_win(now(env))) S$late[k] <- S$late[k] + fill
      S$stock[k] <- S$stock[k] + pal - fill
      x <- S$rec[[get_name(env)]]; x$sku <- k; x$pallets <- pal; x$line <- get_attribute(env, "line")
      assign(get_name(env), x, envir = S$rec)
      load_trucks(fill)
    }) %>%
    send_trucks()

  order <- trajectory("order") %>% set_attribute("trucks", function() {
    S$order_i <- S$order_i + 1L; q <- qty[S$order_i, ]
    ship <- pmin(S$stock, q)
    S$stock <- S$stock - ship; S$backlog <- S$backlog + q - ship
    if (in_win(now(env))) { S$ordered <- S$ordered + q; S$ontime <- S$ontime + ship }
    load_trucks(sum(ship))
  }) %>% send_trucks()

  # production plan: every hour, decide whether to start filling a fermenter
  plan_step <- function() {
    t <- now(env); h <- floor(t)
    horizon <- h + round(P$demand$cover * 168)
    fc <- sum(hourly_mean[(h + 1):max(h + 1, horizon)]) * prod$share
    pos <- (S$stock - S$backlog) * prod$hl_per_pallet + S$wip_hl
    gap <- fc - pos
    need <- any(gap > 0)
    fv_free <- get_server_count(env, "Fermenters") + get_queue_count(env, "Fermenters") < get_capacity(env, "Fermenters")
    bh_ok <- S$pre_brew == 0L && get_capacity(env, "Brewhouse") > 0 && get_queue_count(env, "Brewhouse") == 0
    wh_ok <- sum(S$stock) + sum(S$wip_hl / prod$hl_per_pallet) + hl_pack / min(prod$hl_per_pallet) <= P$warehouse$cap
    if (in_win(t)) {
      key <- if (!need) "no_need" else if (!fv_free) "tanks_full" else if (bh_ok && wh_ok) "brewing" else "other"
      S$plan[key] <- S$plan[key] + 1L
    }
    if (need && fv_free && bh_ok && wh_ok) {
      k <- which.max(gap)
      S$queue_sku <- c(S$queue_sku, k); S$wip_hl[k] <- S$wip_hl[k] + hl_pack; S$pre_brew <- S$pre_brew + 1L
      return(1)
    }
    0
  }
  planner <- trajectory("plan") %>%
    set_attribute("go", plan_step) %>%
    branch(function() as.integer(get_attribute(env, "go") > 0), continue = TRUE, trajectory() %>% activate("batch")) %>%
    timeout(1) %>% rollback(3, times = Inf)

  snapshot <- trajectory("week") %>% timeout(function() {
    w <- round(now(env) / 168)
    if (w >= 1 && w <= weeks) S$weekly[w, ] <- c(w, get_server_count(env, "Fermenters"), get_server_count(env, "Bright tanks"), S$stock, S$backlog)
    0
  })

  failure_traj <- function(res, f) {
    trajectory(paste0("fail_", res)) %>%
      branch(function() as.integer(get_capacity(env, res) > 0), continue = TRUE,
             trajectory() %>% seize(res) %>%
               timeout(function() {
                 d <- f$mttr()
                 if (in_win(now(env))) S$fail[[length(S$fail) + 1]] <- c(res = res, h = d)
                 d
               }) %>% release(res))
  }

  sch <- function(cal, cap) to_schedule(availability(P, cal, weeks), cap)
  env %>%
    add_resource("Brewhouse", sch(P$brewhouse$shift, P$brewhouse$cap), preemptive = TRUE) %>%
    add_resource("Fermenters", P$fv$cap) %>%
    add_resource("Bright tanks", P$bt$cap) %>%
    add_resource("Dispatch", sch(P$dispatch$shift, P$dispatch$cap))
  for (r in fillers) env %>% add_resource(r, sch(P$filler$shift, 1), preemptive = TRUE)
  for (r in labs) env %>% add_resource(r, sch(P$labeller$shift, 1), preemptive = TRUE)
  for (r in pals) env %>% add_resource(r, sch(P$palletiser$shift, 1), preemptive = TRUE)

  env %>%
    add_generator("batch", batch, when_activated(), mon = 0) %>%
    add_generator("order", order, at(orders$t), mon = 0) %>%
    add_generator("plan", planner, at(0), mon = 0) %>%
    add_generator("week", snapshot, at(seq(168, weeks * 168, by = 168) - 1e-6), mon = 0)
  add_fail <- function(res, f) if (!is.null(f))
    env %>% add_generator(paste0("fail_", res), failure_traj(res, f), function() rexp(1, 1 / f$mtbf),
                          mon = 0, priority = 10, preemptible = 10)
  add_fail("Brewhouse", P$brewhouse$failure)
  for (r in fillers) add_fail(r, P$filler$failure)
  for (r in labs) add_fail(r, P$labeller$failure)
  for (r in pals) add_fail(r, P$palletiser$failure)

  env %>% run(until = t1)

  list(env = env, S = S, t0 = t0, t1 = t1, weeks = weeks, hl_pack = hl_pack, prod = prod,
       mon = get_mon_resources(env), week_real = week_real)
}

# ---------------------------------------------------------------------------
# Summaries
# ---------------------------------------------------------------------------
integral <- function(time, value, t0, t1) {
  o <- order(time); time <- time[o]; value <- value[o]
  keep <- !duplicated(time, fromLast = TRUE); time <- time[keep]; value <- value[keep]
  i0 <- findInterval(t0, time); v0 <- if (i0 == 0) 0 else value[i0]
  inside <- time > t0 & time < t1
  tt <- c(t0, time[inside], t1); vv <- c(v0, value[inside])
  sum(vv * diff(tt))
}
clip <- function(a, b, t0, t1) { a <- pmax(a, t0); b <- pmin(b, t1); pmax(0, b - a) }

summarise_rep <- function(R, P) {
  S <- R$S; t0 <- R$t0; t1 <- R$t1; mon <- R$mon; prod <- R$prod
  span <- t1 - t0
  res_group <- function(r) sub("_[0-9]+$", "", r)
  occ <- sapply(split(mon, mon$resource), function(d) c(server = integral(d$time, d$server, t0, t1),
                                                         queue = integral(d$time, d$queue, t0, t1),
                                                         cap = integral(d$time, d$capacity, t0, t1)))
  grp <- res_group(colnames(occ))
  agg <- sapply(split(seq_along(grp), grp), function(i) rowSums(occ[, i, drop = FALSE]))

  recs <- as.list(S$rec)
  g <- function(f) vapply(recs, function(x) if (is.null(x[[f]])) NA_real_ else x[[f]], 0)
  b <- data.frame(fv_got = g("fv_got"), bh_req = g("bh_req"), bh_got = g("bh_got"), ferm_done = g("ferm_done"),
                  bt_got = g("bt_got"), fv_rel = g("fv_rel"), ready = g("ready"), line_got = g("line_got"),
                  packed = g("packed"), sku = g("sku"), pallets = g("pallets"))
  endna <- function(x) ifelse(is.na(x), t1, x)
  fv_blocked <- sum(clip(b$ferm_done, endna(b$bt_got), t0, t1), na.rm = TRUE)
  bt_blocked <- sum(clip(b$ready, endna(b$line_got), t0, t1), na.rm = TRUE)
  fails <- if (length(S$fail)) do.call(rbind, S$fail) else matrix(character(), 0, 2, dimnames = list(NULL, c("res", "h")))
  fail_h <- tapply(as.numeric(fails[, "h"]), res_group(fails[, "res"]), sum)
  fh <- function(gp) if (gp %in% names(fail_h)) fail_h[[gp]] else 0

  wait <- function(a, z) { w <- z - a; ok <- !is.na(w) & a >= t0 & a < t1; if (any(ok)) mean(w[ok]) else NA_real_ }
  packed_in <- !is.na(b$packed) & b$packed >= t0 & b$packed < t1
  hlpp <- prod$hl_per_pallet
  ordered_hl <- sum(S$ordered * hlpp); ontime_hl <- sum(S$ontime * hlpp); late_hl <- sum(S$late * hlpp)

  st_row <- function(gp, label, blocked = 0, co = 0) {
    a <- agg[, gp]
    data.frame(station = label, avail = a[["cap"]] / span, occupied = a[["server"]] / a[["cap"]],
               blocked = blocked / a[["cap"]], breakdown = fh(gp) / a[["cap"]], changeover = co / a[["cap"]],
               active = (a[["server"]] - blocked) / a[["cap"]], queue = a[["queue"]] / span)
  }
  util <- rbind(
    st_row("Brewhouse", P$names[["brewhouse"]]),
    st_row("Fermenters", P$names[["fermentation"]], blocked = fv_blocked),
    st_row("Bright tanks", P$names[["bright"]], blocked = bt_blocked),
    st_row("Filler", P$names[["filler"]], co = S$co_h),
    st_row("Labeller", P$names[["labeller"]]),
    st_row("Palletiser", P$names[["palletiser"]]),
    st_row("Dispatch", P$names[["dispatch"]]))
  wk <- as.data.frame(S$weekly); names(wk) <- c("week", "fv_busy", "bt_busy", paste0("stock_", prod$code), paste0("backlog_", prod$code))
  wk <- wk[!is.na(wk$week) & wk$week > P$demand$warmup, ]
  wh_fill <- mean(rowSums(wk[, paste0("stock_", prod$code), drop = FALSE])) / P$warehouse$cap
  util <- rbind(util, data.frame(station = P$names[["warehouse"]], avail = P$warehouse$cap, occupied = wh_fill, blocked = 0,
                                 breakdown = 0, changeover = 0, active = wh_fill, queue = NA))
  waits <- c(wait(b$bh_req, b$bh_got), wait(b$ferm_done, b$bt_got), wait(b$ready, b$line_got))
  util$wait <- NA_real_
  util$wait[util$station == P$names[["brewhouse"]]] <- waits[1]
  util$wait[util$station == P$names[["bright"]]] <- waits[2]
  util$wait[util$station == P$names[["filler"]]] <- waits[3]

  # weekly packaged output (calendar weeks of the measured year)
  pk <- b[packed_in, ]
  pk_week <- floor(pk$packed / 168) + 1 - P$demand$warmup
  packaged_w <- tabulate(pk_week, 52) * R$hl_pack
  wk$cal <- wk$week - P$demand$warmup
  wk$demand_hl <- R$week_real[wk$week]
  wk$packaged_hl <- packaged_w[wk$cal]

  plan <- S$plan / sum(S$plan)
  list(
    kpi = data.frame(demand_hl = ordered_hl, packaged_hl = sum(packed_in) * R$hl_pack, shipped_hl = ontime_hl + late_hl,
                     service = ontime_hl / ordered_hl, backlog_end_hl = sum(S$backlog * hlpp),
                     batches = sum(packed_in), plan_tanks_full = plan[["tanks_full"]], plan_no_need = plan[["no_need"]],
                     plan_other = plan[["other"]], co_h = S$co_h),
    util = util, weekly = wk)
}

# ---------------------------------------------------------------------------
# Writing results
# ---------------------------------------------------------------------------
slug <- function(x) gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", tolower(x)))
pct <- function(x, d = 0) ifelse(is.na(x), "", sprintf(paste0("%.", d, "f%%"), 100 * x))
ci <- function(x) { m <- mean(x); h <- if (length(x) > 1) qt(0.975, length(x) - 1) * sd(x) / sqrt(length(x)) else 0; c(m, m - h, m + h) }
fmt_n <- function(x) formatC(round(x), big.mark = ",", format = "d")

COL <- list(s1 = "#2a78d6", s2 = "#eb6834", s3 = "#1baf7a", ink = "#0b0b0b", ink2 = "#52514e", grid = "#e7e6e2", bg = "#fcfcfb")
theme_demo <- function() theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = COL$bg, colour = NA), panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = COL$grid, linewidth = 0.3), text = element_text(colour = COL$ink),
        axis.text = element_text(colour = COL$ink2), legend.position = "top", legend.title = element_blank(),
        plot.title = element_text(face = "bold"), plot.title.position = "plot")

bottleneck_of <- function(u, kpi, P_names_line) {
  cand <- u[!is.na(u$active), ]
  # the packaging line runs as one unit: count it once, under the filler that paces it
  cand <- cand[!cand$station %in% c(P_names_line), ]
  o <- order(-cand$active)
  list(name = cand$station[o[1]], active = cand$active[o[1]], second = cand$station[o[2]], second_active = cand$active[o[2]])
}

write_results <- function(scen, P, sums, runtime) {
  dir.create(IMG, showWarnings = FALSE, recursive = TRUE); dir.create(DATA, showWarnings = FALSE, recursive = TRUE)
  sl <- slug(scen$name)
  kpi <- do.call(rbind, lapply(sums, `[[`, "kpi"))
  util_all <- do.call(rbind, lapply(seq_along(sums), function(i) cbind(rep = i, sums[[i]]$util)))
  weekly <- do.call(rbind, lapply(seq_along(sums), function(i) cbind(rep = i, sums[[i]]$weekly)))
  ord <- unique(util_all$station)
  u <- do.call(rbind, lapply(split(util_all, factor(util_all$station, ord)), function(d)
    data.frame(station = d$station[1], avail = mean(d$avail), occupied = mean(d$occupied), blocked = mean(d$blocked),
               breakdown = mean(d$breakdown), changeover = mean(d$changeover), active = mean(d$active),
               queue = mean(d$queue), wait = mean(d$wait, na.rm = TRUE))))
  bn <- bottleneck_of(u, kpi, c(P$names[["labeller"]], P$names[["palletiser"]]))
  sv <- ci(kpi$service); thr <- ci(kpi$packaged_hl); dm <- ci(kpi$demand_hl); bl <- ci(kpi$backlog_end_hl)
  tf <- ci(kpi$plan_tanks_full)

  summary_row <- data.frame(scenario = scen$name, question = scen$fm$question %||% "",
                            overrides = paste(sprintf("%s = %s", names(scen$fm$overrides %||% list()),
                                                      vapply(scen$fm$overrides %||% list(), function(v) paste(unlist(v), collapse = "/"), "")), collapse = "; "),
                            reps = nrow(kpi), service = sv[1], service_lo = sv[2], service_hi = sv[3],
                            packaged_hl = thr[1], packaged_lo = thr[2], packaged_hi = thr[3], demand_hl = dm[1],
                            backlog_end_hl = bl[1], tanks_full = tf[1], bottleneck = bn$name, bottleneck_active = bn$active,
                            fv_active = u$active[u$station == P$names[["fermentation"]]],
                            filler_occ = u$occupied[u$station == P$names[["filler"]]], runtime_s = runtime)
  write.csv(summary_row, file.path(DATA, paste0(sl, ".csv")), row.names = FALSE)
  write.csv(kpi, file.path(DATA, paste0(sl, "-replications.csv")), row.names = FALSE)

  # --- charts
  wk <- aggregate(cbind(demand_hl, packaged_hl) ~ cal, data = weekly, FUN = mean)
  wq <- aggregate(packaged_hl ~ cal, data = weekly, FUN = function(x) quantile(x, c(.1, .9)))
  wk$lo <- wq$packaged_hl[, 1]; wk$hi <- wq$packaged_hl[, 2]
  p1 <- ggplot(wk, aes(cal)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = COL$s2, alpha = 0.18) +
    geom_line(aes(y = demand_hl, colour = "Demand ordered"), linewidth = 0.7) +
    geom_line(aes(y = packaged_hl, colour = "Beer packaged"), linewidth = 0.7) +
    scale_colour_manual(values = c("Demand ordered" = COL$s1, "Beer packaged" = COL$s2)) +
    scale_y_continuous(labels = function(x) format(x, big.mark = ","), limits = c(0, NA)) +
    labs(title = "Weekly demand and packaged output", subtitle = sprintf("Mean of %d replications; band = 10th to 90th percentile of output", nrow(kpi)),
         x = "Week of year", y = "hL per week") + theme_demo()
  ggsave(file.path(IMG, paste0(sl, "-weekly.png")), p1, width = 7.5, height = 3.6, dpi = 150)

  ul <- rbind(data.frame(station = u$station, part = "Working", v = u$active - u$breakdown - u$changeover),
              data.frame(station = u$station, part = "Breakdowns and changeovers", v = u$breakdown + u$changeover),
              data.frame(station = u$station, part = "Blocked (full, waiting downstream)", v = u$blocked))
  ul$station <- factor(ul$station, rev(u$station))
  ul$part <- factor(ul$part, c("Blocked (full, waiting downstream)", "Breakdowns and changeovers", "Working"))
  p2 <- ggplot(ul, aes(v, station, fill = part)) + geom_col(width = 0.6, colour = COL$bg, linewidth = 0.4) +
    scale_fill_manual(values = c("Working" = COL$s1, "Breakdowns and changeovers" = COL$s3, "Blocked (full, waiting downstream)" = COL$s2),
                      breaks = c("Working", "Breakdowns and changeovers", "Blocked (full, waiting downstream)")) +
    scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1.02), expand = c(0, 0)) +
    labs(title = "Utilisation of available time, by station", subtitle = "Warehouse = mean share of pallet positions in use",
         x = NULL, y = NULL) + theme_demo()
  ggsave(file.path(IMG, paste0(sl, "-utilisation.png")), p2, width = 7.5, height = 3.6, dpi = 150)

  stock_cols <- grep("^stock_", names(weekly), value = TRUE); bl_cols <- grep("^backlog_", names(weekly), value = TRUE)
  weekly$stock <- rowSums(weekly[, stock_cols, drop = FALSE]); weekly$backlog <- rowSums(weekly[, bl_cols, drop = FALSE])
  ws <- aggregate(cbind(stock, backlog) ~ cal, data = weekly, FUN = mean)
  ws <- rbind(data.frame(cal = ws$cal, what = "Pallets in stock", v = ws$stock), data.frame(cal = ws$cal, what = "Pallets on back order", v = ws$backlog))
  p3 <- ggplot(ws, aes(cal, v, colour = what)) + geom_line(linewidth = 0.7) +
    geom_hline(yintercept = P$warehouse$cap, colour = COL$ink2, linetype = "dashed", linewidth = 0.3) +
    annotate("text", x = 1, y = P$warehouse$cap, label = "warehouse capacity", hjust = 0, vjust = -0.4, size = 3, colour = COL$ink2) +
    scale_colour_manual(values = c("Pallets in stock" = COL$s1, "Pallets on back order" = COL$s2)) +
    scale_y_continuous(labels = function(x) format(x, big.mark = ",")) +
    labs(title = "Stock and back orders at the end of each week", subtitle = "Mean of replications", x = "Week of year", y = "Pallets") + theme_demo()
  ggsave(file.path(IMG, paste0(sl, "-stock.png")), p3, width = 7.5, height = 3.4, dpi = 150)

  # simmer.plot: fermenter occupancy through the year, replication 1
  m1 <- attr(sums, "mon1")
  if (!is.null(m1)) {
    p4 <- plot(m1, metric = "usage", names = "Fermenters", items = "server", steps = TRUE) +
      labs(title = "Fermenters in use (replication 1, simmer.plot)", subtitle = "Includes the warm-up weeks at the start; dashed line = number of tanks", x = "Simulated hours") + theme_demo()
    ggsave(file.path(IMG, paste0(sl, "-fermenters.png")), p4, width = 7.5, height = 3.2, dpi = 150)
  }

  # --- note
  ov <- scen$fm$overrides %||% list()
  ov_lines <- if (length(ov)) paste0("- `", names(ov), "` = ", vapply(ov, function(v) paste(unlist(v), collapse = ", "), ""), collapse = "\n") else "- none (this is the plant as described in the station and rule notes)"
  ut <- paste0("| ", u$station, " | ", ifelse(u$station == P$names[["warehouse"]], paste(fmt_n(u$avail), "pallet positions"), sprintf("%.1f", u$avail)),
               " | ", pct(u$occupied), " | ", pct(u$blocked), " | ", pct(u$breakdown + u$changeover), " | **", pct(u$active), "** | ",
               ifelse(is.na(u$queue), "", sprintf("%.2f", u$queue)), " | ", ifelse(is.na(u$wait) | is.nan(u$wait), "", sprintf("%.1f", u$wait)), " |", collapse = "\n")
  head_tanks <- if (tf[1] > 0.02) sprintf(" For %s of the year's hours the production plan wanted to brew but every fermenter was full.", pct(tf[1])) else ""
  verdict <- if (sv[1] >= 0.995 && bn$active < 0.85) sprintf("No station is binding: demand is met. The tightest is %s at %s.", bn$name, pct(bn$active)) else
    sprintf("The bottleneck is **%s** (%s of its available time in use, excluding time spent blocked); next tightest is %s at %s.", bn$name, pct(bn$active), bn$second, pct(bn$second_active))
  md <- c("---", "type: result", sprintf("scenario: \"[[%s]]\"", scen$name), sprintf("generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M")),
          sprintf("replications: %d", nrow(kpi)), "simulated: 52 weeks after a warm-up", sprintf("runtime_seconds: %.1f", runtime),
          sprintf("service_level: %.4f", sv[1]), sprintf("bottleneck: \"%s\"", bn$name), "---",
          sprintf("# Results: %s", scen$name), "",
          "*Written by `R/run.R`; do not edit by hand. Synthetic plant: every input is an illustrative assumption or a rule of thumb.*", "",
          if (!is.null(scen$fm$question)) c(sprintf("> **Question:** %s", scen$fm$question), "") else NULL,
          "## Headline", "",
          sprintf("Service level **%s** (95%% interval %s to %s) of %s hL ordered. %s%s", pct(sv[1], 1), pct(sv[2], 1), pct(sv[3], 1), fmt_n(dm[1]), verdict, head_tanks), "",
          "## Changes from the plant notes", "", ov_lines, "",
          "## Throughput and demand (measured year)", "",
          "| Measure | Mean | 95% interval |", "|---|---|---|",
          sprintf("| Demand ordered (hL) | %s | %s to %s |", fmt_n(dm[1]), fmt_n(dm[2]), fmt_n(dm[3])),
          sprintf("| Beer packaged (hL) | %s | %s to %s |", fmt_n(thr[1]), fmt_n(thr[2]), fmt_n(thr[3])),
          sprintf("| Packaged / ordered | %s | |", pct(thr[1] / dm[1], 1)),
          sprintf("| Service level (share shipped on the day ordered) | %s | %s to %s |", pct(sv[1], 1), pct(sv[2], 1), pct(sv[3], 1)),
          sprintf("| Back orders at year end (hL) | %s | %s to %s |", fmt_n(bl[1]), fmt_n(max(0, bl[2])), fmt_n(bl[3])),
          sprintf("| Fermenter fills packaged | %.0f | |", mean(kpi$batches)),
          sprintf("| Hours the plan wanted beer but all fermenters were full | %s | %s to %s |", pct(tf[1]), pct(max(0, tf[2])), pct(tf[3])),
          sprintf("| Changeover hours on the filler | %.0f | |", mean(kpi$co_h)), "",
          paste0("![Weekly demand and output](img/", sl, "-weekly.png)"))
  md <- c(md, "", "## Utilisation per station", "",
          "Share of each station's *available* time (on shift, all units) that it was occupied. **Active** excludes time a tank sat full waiting for the next step, which is a symptom of a constraint downstream, not work. Queue is the time-averaged number of batches (or trucks) waiting; wait is the mean hours a batch waited to get in.", "",
          "| Station | Units on shift (mean) | Occupied | Blocked | Breakdowns + changeovers | Active | Mean queue | Mean wait (h) |",
          "|---|---|---|---|---|---|---|---|", ut, "",
          paste0("![Utilisation by station](img/", sl, "-utilisation.png)"), "",
          paste0("![Stock and back orders](img/", sl, "-stock.png)"), "",
          paste0("![Fermenter occupancy](img/", sl, "-fermenters.png)"), "",
          "## How to read the bottleneck", "",
          "The bottleneck is the station with the highest *active* utilisation. The packaging line (filler, labeller and packer, palletiser) runs as one unit, so the three machines show nearly the same figure; the filler paces it. Wait at Bright tanks is the time beer sat in a full fermenter waiting for a bright tank; wait at the filler is the time beer sat in a bright tank waiting for the line.", "",
          sprintf("Runtime: %.1f s for %d replications. Raw numbers: `Results/data/%s.csv` and `%s-replications.csv`.", runtime, nrow(kpi), sl, sl))
  writeLines(md, file.path(RES, paste0(scen$name, ".md")))
  summary_row
}

write_comparison <- function() {
  fs <- list.files(DATA, pattern = "\\.csv$", full.names = TRUE)
  fs <- fs[!grepl("-replications\\.csv$", fs)]
  if (!length(fs)) return(invisible())
  d <- do.call(rbind, lapply(fs, read.csv, stringsAsFactors = FALSE))
  d$is_base <- d$scenario == "Baseline"
  d <- d[order(!d$is_base, d$scenario), ]
  base <- d[d$is_base, ]
  delta <- function(x, b) if (nrow(base)) sprintf("%+.1f pts", 100 * (x - b)) else ""
  rows <- paste0("| [[", d$scenario, "]] | ", ifelse(d$overrides == "", "none", gsub("\\|", "/", d$overrides)), " | **", pct(d$service, 1), "** (", pct(d$service_lo, 1), " to ", pct(d$service_hi, 1), ") | ",
                 if (nrow(base)) ifelse(d$is_base, "", sapply(d$service, delta, b = base$service)) else "", " | ",
                 fmt_n(d$packaged_hl), " | ", fmt_n(d$backlog_end_hl), " | ", pct(d$fv_active), " | ", pct(d$filler_occ), " | ", pct(d$tanks_full), " | ",
                 d$bottleneck, " | ", sprintf("%.0f", d$runtime_s), " |")
  d$scenario_f <- factor(d$scenario, rev(d$scenario))
  p <- ggplot(d, aes(service, scenario_f)) +
    geom_errorbar(aes(xmin = service_lo, xmax = service_hi), width = 0.25, orientation = "y", colour = COL$ink2, linewidth = 0.4) +
    geom_point(colour = COL$s1, size = 3) +
    scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    labs(title = "Service level by scenario", subtitle = "Share of ordered beer shipped on the day; mean and 95% interval over replications", x = NULL, y = NULL) + theme_demo()
  ggsave(file.path(IMG, "comparison-service.png"), p, width = 7.5, height = 0.6 * nrow(d) + 1.4, dpi = 150)
  md <- c("---", "type: result", "scenario: comparison", sprintf("generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M")), "---",
          "# Comparison of scenarios", "",
          "*Written by `R/run.R --compare`; do not edit by hand. Synthetic plant.*", "",
          "| Scenario | Changes | Service level (95% interval) | vs Baseline | Packaged hL/yr | Back orders at year end (hL) | Fermenters active | Filler occupied | Plan blocked by full tanks | Bottleneck | Runtime (s) |",
          "|---|---|---|---|---|---|---|---|---|---|---|", rows, "",
          "![Service level by scenario](img/comparison-service.png)", "",
          "Each scenario runs the same random-number seeds per replication (common random numbers), so differences between scenarios are less noisy than the intervals suggest.")
  writeLines(md, file.path(RES, "Comparison.md"))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
notes <- load_vault()
types <- vapply(notes, function(n) as.character(n$fm$type %||% ""), "")
scens <- notes[types == "scenario"]

check_all <- function() {
  P0 <- build_params(notes)
  for (s in scens) build_params(apply_overrides(notes, s))
  P0
}

if (opt_check) {
  invisible(check_all())
  cat(sprintf("Vault OK: %d stations routed %s; %d scenarios.\n", sum(types == "station"),
              paste(build_params(notes)$route, collapse = " -> "), length(scens)))
  quit(status = 0)
}
if (opt_compare && !length(scen_args)) { write_comparison(); cat("Wrote Results/Comparison.md\n"); quit(status = 0) }

todo <- if (length(scen_args)) scen_args else names(scens)
miss <- setdiff(todo, names(scens))
if (length(miss)) stop(sprintf("No scenario note called '%s' (scenarios: %s).", miss[1], paste(names(scens), collapse = ", ")), call. = FALSE)
invisible(check_all())

cores <- max(1L, min(n_reps, parallel::detectCores() - 1L))
for (nm in todo) {
  sc <- scens[[nm]]
  P <- build_params(apply_overrides(notes, sc))
  t_start <- Sys.time()
  out <- mclapply(seq_len(n_reps), function(r) {
    R <- run_rep(P, r, seed = 1000 + r)
    s <- summarise_rep(R, P)
    if (r == 1) s$mon <- R$mon
    s
  }, mc.cores = cores, mc.set.seed = FALSE)
  bad <- vapply(out, inherits, TRUE, "try-error")
  if (any(bad)) stop(sprintf("Scenario '%s': replication failed: %s", nm, as.character(out[[which(bad)[1]]])), call. = FALSE)
  runtime <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
  attr(out, "mon1") <- out[[1]]$mon
  row <- write_results(sc, P, out, runtime)
  cat(sprintf("%-32s service %5.1f%%  packaged %s hL  bottleneck %s  (%.1f s, %d reps on %d cores)\n",
              nm, 100 * row$service, fmt_n(row$packaged_hl), row$bottleneck, runtime, n_reps, cores))
}
write_comparison()
