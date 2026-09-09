# pdal-docker

[PDAL](https://pdal.io/) runtime published as `ghcr.io/linz/pdal-docker`, used as the base image for LINZ point cloud processing containers.

## Usage

Pin by digest, so a moved tag cannot change what is built:

```dockerfile
FROM ghcr.io/linz/pdal-docker:2.10.2@sha256:...
```

The image contains `pdal`, its shared libraries and `python3`. Layer your own environment on top of it.

## Publishing

Every push to `master` builds the image, checks that `pdal --version` matches the recipe, and publishes two tags: `<pdal version>` and `<pdal version>-<short sha>`.
The second (`<pdal version>-<short sha>`) distinguishes rebuilds that do not change the PDAL version.

Pull requests build and verify without publishing.

The digest to pin is printed in the workflow run summary.

## Upgrading PDAL

Bump `PDAL_VERSION` and `PDAL_COMMIT` in the `Dockerfile`. The build asserts that the tag resolves to that commit, so a retagged release fails rather than shipping quietly.

## License

This repository is MIT licensed. The image redistributes PDAL under its own BSD licence, reproduced at `/usr/share/doc/pdal/copyright`.
