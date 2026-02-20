# Multi-Architecture Image Manifest Guide (AWS ECR)

This guide shows how to publish a single image tag (for example, `0.111.0`) that supports multiple CPU architectures in Amazon ECR.

It combines architecture-specific images such as:
- `amd64` (Intel/AMD x86_64)
- `arm64` (Apple Silicon / AWS Graviton)

into one manifest list so users can pull the same tag on different platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Workflow 1: Docker Manifest](#workflow-1-docker-manifest)
- [Workflow 2: Buildx Imagetools](#workflow-2-buildx-imagetools)
- [Verify the Manifest](#verify-the-manifest)

## Prerequisites

1. Docker with `manifest` support or Docker `buildx`.
2. Logged in to ECR.
3. Architecture-specific images already pushed to ECR.

Example ECR login:

```bash
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Example repository format:

```text
<account-id>.dkr.ecr.<region>.amazonaws.com/<image-name>
```

## Workflow 1: Docker Manifest

Use this when `amd64` and `arm64` images already exist in ECR.

### 1. Create a manifest list

```bash
docker manifest create <repo>:0.111.0 \
  <repo>:0.111.0-amd64 \
  <repo>:0.111.0-arm64
```

### 2. Annotate architecture metadata

```bash
docker manifest annotate <repo>:0.111.0 <repo>:0.111.0-amd64 --arch amd64
docker manifest annotate <repo>:0.111.0 <repo>:0.111.0-arm64 --arch arm64
```

### 3. Push the manifest to ECR

```bash
docker manifest push <repo>:0.111.0
```

## Workflow 2: Buildx Imagetools

Use this if Docker `buildx` is available. It is concise and CI/CD friendly.

```bash
docker buildx imagetools create \
  -t <repo>:0.111.0 \
  <repo>:0.111.0-amd64 \
  <repo>:0.111.0-arm64
```

## Verify the Manifest

```bash
docker manifest inspect <repo>:0.111.0
```

Confirm both architectures appear in the output (`amd64` and `arm64`).
