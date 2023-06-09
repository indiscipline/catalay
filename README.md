# Catalay <img src="catalay.svg" align="right" alt="Catalay logo" title="Catalay go purrr!" width="30%"/>
[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE.md)

> TLDR: *Write a declarative config, Catalay go purrr, perfect catalogue layout in InDesign ready.*

Catalay is a free software suite designed to automate the layout of image catalogues made with Adobe InDesign, using simple, declarative, human readable and editable configuration files in TOML or YAML formats as input.

The main feature of Catalay is finding the optimal grid layouts for multiple distinctive groups of items, preserving their relative size ratios while filling as much space on the page as possible[^killerfeature].

The main stand-alone program processes the user-provided input files, calculates the best layouts for each page, generates the HTML preview for quick visual inspection and outputs a JSON file, which is then used by the complimentary [Catalay.jsx](#catalayjsx-) script to compile the catalogue in InDesign.

Catalay can significantly reduce the time and effort required for creating complex image catalogues, freeing the users of routine labour and allowing them to focus on less tedious and more meaningful parts of their job. The resulting layouts are highly efficient, precise and ready for fine-tuning.

Although Catalay is tailored for a specific use-case, it probably means it's the only alternative to incessant unassisted drudgery of selecting, moving, resizing and aligning.

| Catalay processes input files, | outputs an HTML preview, | Catalay.jsx compiles the layout. |
| --- | --- | --- |
| <a href="assets/stage1.png"><img src="assets/stage1.png" alt="Stage 1: Catalay processes the input config" width="100%"/></a> | <a href="assets/stage2.png"><img src="assets/stage2.png" alt="Stage 2: Catalay outputs an HTML preview" width="100%"/></a> | <a href="assets/stage3.png"><img src="assets/stage3.png" alt="Catalay.jsx compiles the layout" width="100%"/></a> |

# Table of Contents

- [Usage](#usage)
  * [Usage example](#usage-example)
  * [Input file description](#input-file-description)
  * [Output file description](#output-file-description)
  * [Installation](#installation)
  * [Catalay.jsx](#catalayjsx-)
- [FAQ](#faq)
- [TODO:](#todo)
- [Contributing](#contributing)
- [License](#license)
- [Disclaimer](#disclaimer)

# Usage

Run `catalay --help` to list all the available options.

## Usage example

To create a catalogue with Catalay, download it, install the Catalay.jsx script and follow these steps:

1. Create a configuration file in either TOML or YAML format, following the configuration file description below.
2. Run `catalay MY_CONFIG.toml`, substituting the name of the config file.
3. Inspect the produced layout opening `preview.html` (saved along the output JSON) in your browser.
4. Open InDesign, open the *Scripts panel* and run the Catalay.jsx script.
5. Select the produced output file in the opened file dialog and follow along.
6. Catalay.jsx will compile the new catalogue, filling the rectangle placeholders with the appropriate images and text.

During its execution, Catalay will print the calculation statistics and save the results to `out.json` (or the provided file path). Unless the `-H` option was used, Catalay will also save the `preview.html` with all the pages. Individual page layouts can also be saved as SVG files using the `--svg` option.

## Input file description

Config files for Catalay are meant to be the only thing the user needs to spend his time on to layout and compile the catalogue.

Catalay supports input in TOML and YAML formats with an identical schema. A config file describes the basic page preferences for the document and properties of the images that will be included in the catalogue. The format is designed for simple integration in common spreadsheet-heavy work environments.

A thorough description of the input format is included in the example files ([TOML](src/example.toml), [YAML](src/example.yaml)) available from the program:

```
# Print the annotated input configuration in TOML:
catalay --exampleToml

# Print the annotated input configuration in YAML:
catalay --exampleYaml
```
To save the examples to a file, use redirection: `catalay --exampleToml > in.toml`.

## Output file description

Catalay generates an HTML preview of the catalogue layout for quick visual inspection and finetuning of the input, and the main JSON file for Catalay.jsx to process and compile in InDesign.

This multi-step process was chosen for:

- The ease of integrating into various workflows and simplifying the possible interaction with other tools
- Increased overall performance
- Separation of concerns that lowers the barrier to entry for further development

## Installation

Catalay is tested to work under Windows and GNU/Linux. It should work on macOS with no changes.

Download the Catalay binary or the source code and Catalay.jsx from the [release assets](https://github.com/indiscipline/catalay/releases/latest).

The program can be compiled with all the dependencies by using Nim's Nimble package manager with the following command:

```
nimble install http://github.com/indiscipline/catalay
```

## Catalay.jsx <img src="catalay.jsx/catalay.jsx.svg" align="right" alt="Catalay.jsx logo" width="20%"/>

Catalay.jsx is a script for Adobe InDesign. It reads the output JSON file produced by the main program and compiles the catalogue. Install it following [Adobe documentation](https://helpx.adobe.com/indesign/using/scripting.html):

> A quick way to locate the Scripts Panel folder is to right-click (Windows) or Control-click (macOS) a script in the Scripts panel and choose Reveal In Explorer (Windows) or Reveal In Finder (macOS).

Additional information on Catalay.jsx available in its own [readme](Catalay.jsx/README.md).


# FAQ

- > Why doesn't this program have feature X?

We encourage users to file feature requests and bug reports as issues in this repository. Even though the author cannot guarantee your request will be implemented, any feedback (including negative) is useful and much appreciated.

- > I click on the program executable and nothing opens, is it broken?

No, Catalay is a command-line interface (CLI) program. You need to run it from a terminal or Command Prompt. **On Windows** you can open a command prompt by pressing Win+R, typing `cmd`, and pressing Enter. **On macOS**: press Cmd+Space to open spotlight search, type `terminal` and press return. **On GNU\Linux**… really? Or, may be it *is* broken. [File a bug report](https://github.com/indiscipline/catalay/issues/new) then!

- > How exactly does the program calculate the optimal layout?

Catalay uses a combination of a simple heuristic and a stochastic optimization algorithm to calculate the grid layout for multiple distinctive groups of items on a page in a close to optimal way and in constant time.

- > Why is it free (noncommercial)?

Catalay is a niche tool and not likely to generate significant interest, even though it's designed (and battle tested) to be useful in a *work* situation, where it proved to save time. If you happen to find Catalay useful, consider making a donation[^donations]. Just sharing it with others or contacting the author is great too. Catalay is released as Free Software because it's the only right thing to do.

- > What's with the logo?

It's a cat, it lays on a catalogue. It probably purrs.


# TODO

- [ ] Introduce group weights to quickly fine-tune relative scaling of the image groups on the page. For now you can just tweak the group sizes.
- [ ] Support omitting group titles. For now it's possible to just leave the group title field empty (""), but the space will not be reused for image placement.
- [ ] Introduce additional layout constraints, such as minimal item margin.


# Contributing

The project is open for contributions. Open an [issue](https://github.com/indiscipline/catalay/issues/) for bugs, ideas and feature requests.


# License

Catalay and Catalay.jsx are licensed under GNU General Public License version 3.0 or later; See [`LICENSE.md`](LICENSE.md) for full details.

[Catalay](catalay.svg) and [Catalay.jsx](catalay.jsx/catalay.jsx.svg) logos are licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)


# Disclaimer

Adobe InDesign product and logo are trademarks™ or registered® trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.

[^killerfeature]: Why is this useful? Most catalogues represent real world items. Preserving more specifics of their appearance, such as their relative dimensions, in printed media helps users make informed decisions and helps the sales people justifying their pricing policies.

[^donations]: There's [a couple of options](https://indiscipline.github.io/about#donations) on author's "About" page.
