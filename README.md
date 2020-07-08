# My online CV

## Automated project to generate the html and pdf version of my CV

![Build and deploy](https://github.com/willvieira/cv/workflows/Build%20and%20deploy/badge.svg) [![html](https://img.shields.io/badge/read-html-blue)](https://willvieira.github.io/cv/index.html) [![pdf](https://img.shields.io/badge/read-pdf-yellow)](https://willvieira.github.io/cv/WillianVieira.pdf) 


It is built to programmatically (twice a month) retrieve my publications from ORCID and generate a list of updated publications.


## Setup

### Authentication on GitHub actions

- To retrieve ORCID data, you first need to generate a token as explained in the `{rorcid}` R package [homepage](https://github.com/ropensci/rorcid#authentication)
- Save your generated token as a secret on your GitHub repo (explained [here](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-an-organization)), so it can be accessed by the GitHub actions
