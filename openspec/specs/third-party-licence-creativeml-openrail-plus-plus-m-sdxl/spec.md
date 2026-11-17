# Third-party licence: creativeml-openrail-plus-plus-m-sdxl

@trace spec:third-party-licence-creativeml-openrail-plus-plus-m-sdxl

## Purpose
This project depends on stabilityai/stable-diffusion-xl-base-1.0 and must now adhere to use-based restrictions, output accountability, attribution and review, the obligations its licence `creativeml-openrail-plus-plus-m-sdxl` (CreativeML Open RAIL++-M License dated July 26, 2023, Copyright (c) 2023 Stability AI) carries. The operator signs the acknowledgement on the host, one record per artefact, as `licences/acknowledgements/creativeml-openrail-plus-plus-m-sdxl--<artefact-slug>.yaml` with use `non-sale`. SDXL base 1.0 is the checkpoint of twelve committed image workflows: sprites, backgrounds, comms portraits and backdrops, and widescreen frames. The weights stay in the host studio's model store and this project never redistributes them. Text: `licences/texts/creativeml-openrail-plus-plus-m-sdxl.md` (sha256 `19b6998b569b53ac1fc2158a8a3202c8699a9a4605b47075715d9c96be7fb6d0`); research and pins: `plan/licences-round-2.md`.

The clauses this spec relies on, verbatim from the text:
- Line 33: "Use-based restrictions. The restrictions set forth in Attachment A are considered Use-based restrictions. Therefore You cannot use the Model and the Derivatives of the Model for the specified restricted uses." The same paragraph ends: "You shall require all of Your users who use the Model or a Derivative of the Model to comply with the terms of this paragraph (paragraph 5)."
- Line 34: "The Output You Generate. Except as set forth herein, Licensor claims no rights in the Output You generate using the Model. You are accountable for the Output you generate and its subsequent uses. No use of the output can contravene any provision as stated in the License."
- Line 37: "Licensor reserves the right to restrict (remotely or otherwise) usage of the Model in violation of this License"
- Lines 46-59: Attachment A, "You agree not to use the Model or Derivatives of the Model:" followed by the restricted uses.

How this project honours them:
- The models run only through the committed workflows under `art/workflows/`. Their prompts describe fictional demons, ships, terrain and pilots, and no workflow depicts a real person, a minor or personal data.
- Picks are logged with their recipe in `plan/render-runs/` and on the contact sheets in `art/contact/`.
- `tools/generate_credits.lua` lists each covered model with its licence in the "Original art, score and voices" section of `assets/credits.json`. The licence asks for no credit line of its own; the credit follows the project's rule that the credits list every model and licence (`plan/licences-to-sign.md`, operator decision of 2026-11-16).
- The acknowledgement records use `non-sale`.

## Requirements

### Requirement: Use-based restrictions
The project SHALL NOT use stabilityai/stable-diffusion-xl-base-1.0, or any model derived from them, for any use that Attachment A of the licence lists, and SHALL use them only to make art for a free, non-commercial game.

#### Scenario: A workflow is checked against Attachment A
- **WHEN** a new or changed workflow loads one of these models
- **THEN** its prompts and inputs are checked against Attachment A (lines 46-59) before any of its renders is picked

#### Scenario: A restricted use is declined
- **WHEN** someone proposes a use that Attachment A lists
- **THEN** the proposal is declined under this spec

### Requirement: Output accountability
The project SHALL treat every picked render as its own output, accountable for its use under the licence, and SHALL keep each pick's recipe (workflow, seed, model) in the run ledger.

#### Scenario: A shipped image is traced to its model
- **WHEN** a reviewer asks which model made a shipped image
- **THEN** the run ledger names its workflow, seed and model

### Requirement: Attribution
The project SHALL name each model this licence covers, with the licence's name, in the game's credits.

#### Scenario: Credits name the model
- **WHEN** a player or reviewer opens the game's credits
- **THEN** they find each covered model listed with the licence's name

### Requirement: Review
The project SHALL review this acknowledgement again before any use beyond non-sale game art, and before redistributing any weights, which would also oblige it to pass on the licence and its use-based restrictions.

#### Scenario: Wider use waits for a review
- **WHEN** someone proposes selling assets made with these models, or bundling the weights
- **THEN** the work waits for a new signed acknowledgement, made after the operator reads the licence again
