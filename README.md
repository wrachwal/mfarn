MFArn
=====

Mix sub-task printing warnings about remote calls (MFA) unable to find in the project.

## Configuration

Add the following line on the project function of mix.exs file:

- `aliases: [compile: ["compile", "mfarn"]]`

and mfarn as a dependency:

- `{:mfarn, git: "https://github.com/wrachwal/mfarn.git"}`
