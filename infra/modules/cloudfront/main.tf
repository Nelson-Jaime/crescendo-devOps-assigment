locals {
  origin_id = "alb"

  # AWS managed policy IDs (stable, documented by AWS). See ADR 0007.
  cache_policy_caching_disabled                   = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
  cache_policy_caching_optimized                  = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  origin_request_policy_all_viewer_and_cloudfront = "33f36d7e-f396-46d9-90e0-52428a34d9dc" # Managed-AllViewerAndCloudFrontHeaders-2022-06
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} Magnolia CMS"
  http_version        = "http2and3"
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment

  origin {
    origin_id   = local.origin_id
    domain_name = var.origin_domain_name

    # HTTP to the ALB: no custom domain means no ACM certificate (ADR 0006, known limitation).
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }
  }

  # Dynamic content: never cached by default, all methods allowed (the CMS needs POST/PUT).
  default_cache_behavior {
    target_origin_id         = local.origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = local.cache_policy_caching_disabled
    origin_request_policy_id = local.origin_request_policy_all_viewer_and_cloudfront
  }

  # Static assets: cached at the edge.
  dynamic "ordered_cache_behavior" {
    for_each = var.static_path_patterns

    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = local.origin_id
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      cache_policy_id        = local.cache_policy_caching_optimized
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
