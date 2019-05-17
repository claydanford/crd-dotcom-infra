provider "aws" {
  region = "${var.region}"
}

data "aws_acm_certificate" "certificate" {
  domain = "claydanford.com"
}

data "aws_route53_zone" "zone" {
  name         = "claydanford.com."
  private_zone = false
}

resource "random_uuid" "name" {}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.application}-${random_uuid.name.result}"
  acl    = "public-read"

  policy = <<POLICY
{
	  "Version": "2012-10-17",
	  "Statement": [
        {
		        "Sid": "PublicReadGetObject",
		        "Effect": "Allow",
		        "Principal": "*",
		        "Action": "s3:GetObject",
		        "Resource": "arn:aws:s3:::${var.application}-${random_uuid.name.result}/*"
	    }
    ]
}

POLICY

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  versioning {
    enabled = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 1800
  }

  tags = {
    Name        = "${var.application}-${random_uuid.name.result}"
    Application = "${var.application}"
  }
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name = "${aws_s3_bucket.bucket.website_endpoint}"
    origin_id   = "origin-bucket-${aws_s3_bucket.bucket.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  aliases = ["claydanford.com", "www.claydanford.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.bucket.id}"
    min_ttl          = 0
    default_ttl      = 86400
    max_ttl          = 31536000

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${data.aws_acm_certificate.certificate.arn}"
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only"
  }

  tags = {
    Name        = "${var.application}-cloudfront-distribution"
    Application = "${var.application}"
  }
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "www.claydanford.com"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cloudfront.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cloudfront.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "apex" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "claydanford.com"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cloudfront.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cloudfront.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_ssm_parameter" "s3_ssm_param" {
  name      = "/${var.application}/s3-bucket"
  type      = "SecureString"
  value     = "${aws_s3_bucket.bucket.id}"
  overwrite = true

  tags = {
    Application = "${var.application}"
  }
}

resource "aws_ssm_parameter" "cloudfront_ssm_param" {
  name      = "/${var.application}/cf-distro"
  type      = "SecureString"
  value     = "${aws_cloudfront_distribution.cloudfront.id}"
  overwrite = true

  tags = {
    Application = "${var.application}"
  }
}
