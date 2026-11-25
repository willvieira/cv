# syntax=docker/dockerfile:1.7
#
# Reproduces the CI environment of the last successful "Build and deploy" run
# (run 38713808980, 2026-10-15, commit 4a19cc7):
#   - GitHub runner image ubuntu-24.04 (20261012.334)
#   - R 4.2.0 (r-lib/actions/setup-r, Posit r-builds)
#   - pandoc 2.17.1
#   - Google Chrome 155.0.8059.39 (pagedown::chrome_print)
#   - packages from renv.lock, built from source against the 2026-10-15 P3M snapshot
#
# The image holds the environment only; the repo is mounted at run time:
#   docker build -t cv-build .
#   docker run --rm -e ORCID_TOKEN -v "$PWD:/project" cv-build
# Outputs land in docs/ (index.html and WillianVieira.pdf), as in CI.

FROM --platform=linux/amd64 ubuntu:24.04

ARG SNAPSHOT_DATE=2026-10-15
ARG R_VERSION=4.2.0
ARG PANDOC_VERSION=2.17.1
ARG CHROME_VERSION=155.0.8059.39

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    TZ=UTC

# Freeze Ubuntu packages to the day of the build
RUN apt-get update --snapshot "$(echo ${SNAPSHOT_DATE} | tr -d -)T000000Z" \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip locales git \
      # system requirements of the locked R packages
      libcurl4-openssl-dev libssl-dev libxml2-dev zlib1g-dev \
      libfontconfig1-dev libfreetype-dev libharfbuzz-dev libfribidi-dev \
      libpng-dev libjpeg-dev libtiff-dev \
      # what setup-r installs on the runner
      qpdf ghostscript \
      # Chrome runtime libraries and fonts
      libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
      libcairo2 libcups2t64 libdbus-1-3 libdrm2 libexpat1 libgbm1 \
      libglib2.0-0t64 libnspr4 libnss3 libpango-1.0-0 libudev1 libvulkan1 \
      libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
      libxkbcommon0 libxrandr2 fonts-liberation fonts-dejavu-core \
 && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
 && rm -rf /var/lib/apt/lists/*

# R, same build as r-lib/actions/setup-r (pulls compilers as dependencies)
RUN curl -fsSLo /tmp/r.deb "https://cdn.posit.co/r/ubuntu-2404/pkgs/r-${R_VERSION}_1_amd64.deb" \
 && apt-get update --snapshot "$(echo ${SNAPSHOT_DATE} | tr -d -)T000000Z" \
 && apt-get install -y --no-install-recommends /tmp/r.deb \
 && ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R \
 && ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript \
 && rm -rf /tmp/r.deb /var/lib/apt/lists/*

RUN curl -fsSLo /tmp/pandoc.deb "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb" \
 && dpkg -i /tmp/pandoc.deb && rm /tmp/pandoc.deb

# Chrome for Testing keeps every version available; stable .debs are removed
# Docker's default seccomp profile blocks Chrome's sandbox, so a wrapper adds
# --no-sandbox and the render command stays identical to CI
RUN curl -fsSLo /tmp/chrome.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" \
 && unzip -q /tmp/chrome.zip -d /opt && rm /tmp/chrome.zip \
 && printf '#!/bin/sh\nexec /opt/chrome-linux64/chrome --no-sandbox "$@"\n' > /usr/local/bin/chrome \
 && chmod +x /usr/local/bin/chrome
ENV PAGEDOWN_CHROME=/usr/local/bin/chrome

RUN useradd -m cv && mkdir -p /project /opt/renv && chown cv:cv /project /opt/renv
USER cv
WORKDIR /project

# Library lives outside /project so mounting the repo does not hide it
ENV RENV_PATHS_LIBRARY=/opt/renv/library \
    RENV_PATHS_CACHE=/opt/renv/cache \
    RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/__linux__/noble/${SNAPSHOT_DATE}

COPY --chown=cv:cv renv.lock .Rprofile ./
COPY --chown=cv:cv renv/activate.R renv/settings.dcf renv/
RUN Rscript -e 'renv::restore(prompt = FALSE)'

# Same as CI: untagged root build, application_tag.txt is ignored
ENV GITHUB_ACTIONS=true

CMD ["bash", "-c", "set -e \
  && Rscript -e \"rmarkdown::render('index.Rmd')\" \
  && Rscript -e \"pagedown::chrome_print(input = 'index.html', output = 'index.pdf', wait = 5)\" \
  && mkdir -p docs \
  && mv index.html docs/index.html \
  && mv index.pdf docs/WillianVieira.pdf"]
