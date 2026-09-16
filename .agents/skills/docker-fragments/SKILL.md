---
name: docker-fragments
description: Add or substantially change BTCPay Server Docker Compose generator fragments. Use for files under docker-compose-generator/docker-fragments, fragment dependencies or incompatibilities, new fragment images, and cryptocurrency fragment integration.
---

# Docker Fragments

Use this workflow for supported fragments committed to the repository. For an
operator's private override, direct them to the custom-fragment documentation
instead of committing a `.custom.yml` file.

## Establish Requirements

1. Read `docs/development.md#add-a-fragment` and the repository `AGENTS.md`.
2. Identify the services being added or extended, supported architectures,
   persistent state, operator inputs, credentials, host ports, public routes,
   dependencies, conflicts, backup needs, and upgrade expectations.
3. Inspect fragments with the same shape. Prefer current core examples over
   copying an old integration commit.
4. Confirm that a maintained, versioned container image and verifiable source
   provenance exist before integrating a new third-party service.

## Implement the Integration

1. Follow the naming, merge, metadata, and service rules in the maintainer
   documentation. Do not assume standard Compose override semantics.
2. Keep the fragment focused. Coordinate changes to cryptocurrency definitions,
   operational scripts, backup behavior, or generator code only when the
   integration requires them.
3. If the service needs bundled Nginx exposure, load the `nginx-routes` skill
   and follow it for the route snippet and fragment metadata.
4. Update `docs/fragments.md` and add focused operator documentation when the
   fragment introduces configuration or security decisions.
5. Account for every new or changed image in
   `contrib/DockerFileBuildHelper`. Follow the generated-image procedure in
   `AGENTS.md`; never edit generated image artifacts manually.

## Validate

1. Run the temporary generation recipe in
   `docs/development.md#validate-the-fragment` with a representative selection.
2. Inspect the generated Compose service and `manifest.json`, not only the
   generator exit code. Exercise dependency, exclusion, incompatibility, route,
   and secret behavior that the fragment declares.
3. Run the focused non-destructive tests from `AGENTS.md` for each affected
   subsystem and add regression coverage for generator behavior when needed.
4. Do not run `.github/scripts/test-install.sh` on a development machine. Do
   not use `build.sh` merely to validate generation because it has operational
   host and container side effects.
5. Regenerate image artifacts when image references change, check the second
   generation is clean, and finish with `git diff --check`.
