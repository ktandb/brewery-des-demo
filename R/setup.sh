#!/bin/sh
# Install simmer + simmer.plot into ~/Rlibs/brewery-des for the conda R on the butler.
#
# Why this is odd: the butler has no Xcode command-line tools, so simmer (C++)
# cannot be compiled from source, and conda-forge has no osx-arm64 r-simmer.
# Instead we take CRAN's prebuilt arm64 binary (built for CRAN's R 4.5) and
# point its libR link at the conda R's libR.dylib, then re-sign it ad hoc.
# simmer.plot is pure R and installs from source normally.
#
# On a machine with a normal CRAN R (or Xcode tools), just run:
#   Rscript -e 'install.packages(c("simmer","simmer.plot","yaml","ggplot2"))'
set -e
R_HOME_BIN=${R_HOME_BIN:-$HOME/miniconda/envs/renv/bin}
LIB=$HOME/Rlibs/brewery-des
SIMMER=simmer_4.4.7.tgz
mkdir -p "$LIB"
TMP=$(mktemp -d)
curl -sSL -o "$TMP/$SIMMER" "https://cloud.r-project.org/bin/macosx/big-sur-arm64/contrib/4.5/$SIMMER"
tar xzf "$TMP/$SIMMER" -C "$LIB"
SO="$LIB/simmer/libs/simmer.so"
CONDA_LIBR=$("$R_HOME_BIN/Rscript" -e 'cat(file.path(R.home("lib"), "libR.dylib"))')
"$R_HOME_BIN/install_name_tool" -change \
  /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libR.dylib "$CONDA_LIBR" "$SO"
/usr/bin/codesign -f -s - "$SO"
"$R_HOME_BIN/Rscript" -e ".libPaths(c('$LIB', .libPaths())); install.packages('simmer.plot', lib = '$LIB', repos = 'https://cloud.r-project.org'); library(simmer); library(simmer.plot); cat('ok\n')"
echo "Downloaded archive left in $TMP (delete it by hand if you like)."
