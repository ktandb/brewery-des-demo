# Coloured plant canvases: vault/Canvas/<Scenario>.canvas and Comparison.canvas (JSON Canvas, Obsidian's format).
#
#   Rscript R/canvas.R          (run.R also calls this after every run)
#
# Each station is a card linked to its note, coloured by active utilisation, with the bottleneck marked;
# arrows follow the next: links. Reads vault/Stations/*.md and vault/Results/data/<scenario>-stations.csv.
# Layout: if a canvas already exists, its card positions are kept (so you can drag cards around in Obsidian),
# snapped to a 20 px grid so a nudge doesn't make a noisy diff. New cards get a default serpentine layout.
local({
  args <- commandArgs(trailingOnly = FALSE)
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1] %||% "R/canvas.R")))
  root <- if (exists("ROOT")) ROOT else normalizePath(file.path(here, ".."))
  lib <- path.expand("~/Rlibs/brewery-des"); if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))
  suppressPackageStartupMessages({ library(yaml); library(jsonlite) })
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
  vault <- file.path(root, "vault"); data <- file.path(vault, "Results", "data"); out <- file.path(vault, "Canvas")
  dir.create(out, showWarnings = FALSE)
  slug <- function(x) gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", tolower(x)))
  snap <- function(v) as.integer(round(v / 20) * 20)

  # stations and routing from the notes
  fm_of <- function(p) { l <- readLines(p, warn = FALSE, encoding = "UTF-8"); e <- which(trimws(l) == "---")
    if (length(e) < 2 || e[1] != 1) list() else yaml.load(paste(l[2:(e[2] - 1)], collapse = "\n")) }
  files <- list.files(file.path(vault, "Stations"), pattern = "\\.md$", full.names = TRUE)
  st <- setNames(lapply(files, fm_of), sub("\\.md$", "", basename(files)))
  nxt <- vapply(st, function(f) { x <- f[["next"]] %||% ""; m <- regmatches(x, regexec("\\[\\[([^]|#]+)", x))[[1]]
    if (length(m)) trimws(m[2]) else NA_character_ }, "")
  # route order: start from the station nothing points to, follow next:
  start <- setdiff(names(st), nxt[!is.na(nxt)])[1]; route <- start
  while (!is.na(nxt[[tail(route, 1)]]) && !(nxt[[tail(route, 1)]] %in% route)) route <- c(route, nxt[[tail(route, 1)]])
  route <- c(route, setdiff(names(st), route))

  colour <- function(a) if (is.na(a)) "#9a968a" else if (a >= .9) "#c0352a" else if (a >= .75) "#e07b39" else if (a >= .5) "#d9a43a" else "#3a9a5b"
  pct <- function(x) if (is.na(x)) "–" else sprintf("%.0f%%", 100 * x)
  W <- 260; H <- 150; GX <- 340; GY <- 260
  default_xy <- function(i) { row <- (i - 1) %/% 4; col <- (i - 1) %% 4; if (row %% 2 == 1) col <- 3 - col
    c(x = col * GX, y = 140 + row * GY) }   # serpentine, so the route reads like a factory floor

  card_text <- function(s, u, bn) {
    r <- u[u$station == s, ]
    lines <- c(sprintf("**[[%s]]**", s))
    if (nrow(r)) {
      lines <- c(lines, sprintf("Active: **%s**", pct(r$active)))
      if (!is.na(r$blocked) && r$blocked > 0.005) lines <- c(lines, sprintf("Blocked (full, waiting): %s", pct(r$blocked)))
      if (!is.na(r$wait)) lines <- c(lines, sprintf("Mean wait: %.1f h", r$wait))
    }
    if (identical(s, bn)) lines <- c(lines, "", "**▲ Bottleneck**")
    paste(lines, collapse = "\n")
  }

  write_canvas <- function(path, nodes, edges) {
    j <- toJSON(list(nodes = nodes, edges = edges), auto_unbox = TRUE, pretty = TRUE)
    writeLines(j, path, useBytes = TRUE)
  }
  old_xy <- function(path) {
    if (!file.exists(path)) return(list())
    cv <- tryCatch(fromJSON(path, simplifyVector = FALSE), error = function(e) NULL); if (is.null(cv)) return(list())
    setNames(lapply(cv$nodes, function(n) c(x = n$x, y = n$y)), vapply(cv$nodes, `[[`, "", "id"))
  }

  sums <- list.files(data, pattern = "\\.csv$", full.names = TRUE)
  sums <- sums[!grepl("-(replications|stations)\\.csv$", sums)]
  rows <- do.call(rbind, lapply(sums, read.csv, stringsAsFactors = FALSE))
  rows <- rows[order(rows$scenario != "Baseline", -rows$service), ]

  for (k in seq_len(nrow(rows))) {
    sc <- rows$scenario[k]; f <- file.path(data, paste0(slug(sc), "-stations.csv"))
    if (!file.exists(f)) { message("canvas: no station data for ", sc, " (re-run R/run.R)"); next }
    u <- read.csv(f, stringsAsFactors = FALSE); path <- file.path(out, paste0(sc, ".canvas")); keep <- old_xy(path)
    nodes <- list(list(id = "title", type = "text", x = 0L, y = 0L, width = 3 * GX + W, height = 100L,
      text = sprintf("## %s\nService level **%.1f%%** (95%% interval %.1f–%.1f) · bottleneck **%s** · [[Results/%s|full results]]",
                     sc, 100 * rows$service[k], 100 * rows$service_lo[k], 100 * rows$service_hi[k], rows$bottleneck[k], sc)))
    for (i in seq_along(route)) {
      s <- route[i]; id <- slug(s); xy <- keep[[id]] %||% default_xy(i)
      a <- if (s %in% u$station) u$active[u$station == s] else NA
      nodes[[length(nodes) + 1]] <- list(id = id, type = "text", x = snap(xy[["x"]]), y = snap(xy[["y"]]), width = W, height = H,
                                        color = colour(a), text = card_text(s, u, rows$bottleneck[k]))
    }
    nodes[[length(nodes) + 1]] <- list(id = "key", type = "text", x = 0L, y = snap(140 + 2 * GY), width = 3 * GX + W, height = 80L,
      text = "Colour = active utilisation: green under 50% · amber 50–75% · orange 75–90% · red 90% and over. Drag cards to rearrange; positions are kept on the next run.")
    edges <- lapply(route[route %in% names(nxt) & !is.na(nxt[route])], function(s)
      list(id = paste0(slug(s), "--", slug(nxt[[s]])), fromNode = slug(s), toNode = slug(nxt[[s]]), toEnd = "arrow"))
    write_canvas(path, nodes, edges)
  }

  # comparison: one row per scenario, small cards in route order
  nodes <- list(); y <- 0L; w <- 150L; h <- 70L; gx <- 170L
  for (k in seq_len(nrow(rows))) {
    sc <- rows$scenario[k]; f <- file.path(data, paste0(slug(sc), "-stations.csv")); if (!file.exists(f)) next
    u <- read.csv(f, stringsAsFactors = FALSE)
    nodes[[length(nodes) + 1]] <- list(id = paste0("g-", slug(sc)), type = "group", x = 0L, y = y, width = as.integer(length(route) * gx + 20), height = 130L,
                                      label = sprintf("%s: service %.1f%%", sc, 100 * rows$service[k]))
    for (i in seq_along(route)) {
      s <- route[i]; a <- if (s %in% u$station) u$active[u$station == s] else NA
      nodes[[length(nodes) + 1]] <- list(id = paste0(slug(sc), "-", slug(s)), type = "text", x = as.integer(10 + (i - 1) * gx), y = y + 40L,
        width = w, height = h, color = colour(a),
        text = sprintf("%s\n**%s**%s", s, pct(a), if (identical(s, rows$bottleneck[k])) " ▲" else ""))
    }
    y <- y + 170L
  }
  write_canvas(file.path(out, "Comparison.canvas"), nodes, list())
  cat(sprintf("Wrote %d scenario canvases + Canvas/Comparison.canvas\n", nrow(rows)))
})
