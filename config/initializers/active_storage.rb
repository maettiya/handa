# Disable request checksum for Cloudflare R2 compatibility
# R2 doesn't support the newer S3 checksum algorithms

require "aws-sdk-s3"

Aws.config.update(
  request_checksum_calculation: "when_required",
  response_checksum_validation: "when_required"
)
