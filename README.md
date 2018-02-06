# STILT Documentation

Built by Jekyll, Github, and Ben Fasoli.

# Website Structure

The main pages include `index.html` (home splash page), `about.html` (basic description of the STILT model), and files in the `docs/` and `tutorials/` directories.

Files contained in `_includes/` and `_layouts` serve as templates and reusable components for building the pages.

Styling is primarily done using `_sass/_base.scss` and leverages bootstrap alongside several custom container classes for formatting.

The webpage is built automatically using Github pages built-in Jekyll continuous integration.

# Running Locally

To clone the source code for the STILT webpage,

```sh
git clone https://github.com/uataq/stilt/
cd stilt
git checkout gh-pages
```

To run a development environment locally,

```sh
jekyll serve
```

and open a web browser to [localhost:4000/stilt/](localhost:4000/stilt/).
