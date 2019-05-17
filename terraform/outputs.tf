output "hosted_zone_id" {
  value = "${aws_s3_bucket.bucket.hosted_zone_id}"
}

output "id" {
  value = "${aws_s3_bucket.bucket.id}"
}

output "website_endpoint" {
  value = "${aws_s3_bucket.bucket.website_endpoint}"
}
