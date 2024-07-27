resource "aws_s3_bucket" "cdb-eda-converter" {
  bucket = "cdbedaconverterinput5734465567"
}

resource "aws_s3_bucket" "cdb-eda-output" {
  bucket = "cdbedaconverteroutput5734465567"
}

resource "aws_s3_bucket_acl" "eda-converter_acl" {
  bucket = aws_s3_bucket.cdb-eda-output.id
  acl    = "private"
}

resource "aws_cloudfront_distribution" "cattube_origin" {
  origin {
    domain_name = aws_s3_bucket.cdb-eda-output.bucket_regional_domain_name
    origin_id   = "cdbedaconverteroutput"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "cdbedaconverteroutput"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "cattube-origin"
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access Identity for cdbedaconverteroutput"
}

resource "aws_s3_bucket_policy" "cdb-eda-output_policy" {
  bucket = aws_s3_bucket.cdb-eda-output.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.origin_access_identity.id}"
        },
        Action   = "s3:GetObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.cdb-eda-output.bucket}/*"
      }
    ]
  })
}

resource "aws_media_convert_queue" "eda-converter" {
  name = "catqueue"
}

data "archive_file" "ziplambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/function.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_lambda_function" "mediaconverteda" {
  filename         = data.archive_file.ziplambda.output_path
  source_code_hash = data.archive_file.ziplambda.output_base64sha256
  function_name    = "mediaconverteda"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.8"
}

resource "aws_s3_bucket_notification" "cdb-eda-converter-input-notification" {
  bucket = aws_s3_bucket.cdb-eda-converter.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.mediaconverteda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_to_call_lambda]
}

resource "aws_lambda_permission" "allow_s3_to_call_lambda" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mediaconverteda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cdb-eda-converter.arn
}

resource "aws_sns_topic" "s3_notifications" {
  name = "s3-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.s3_notifications.arn
  protocol  = "email"
  endpoint  = "your-email@example.com" # Your e-mail goes here :D
}

resource "aws_s3_bucket_notification" "cdb-eda-output-notification" {
  bucket = aws_s3_bucket.cdb-eda-output.id

  topic {
    topic_arn = aws_sns_topic.s3_notifications.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_iam_role" "mediaconvert_role" {
  name = "MediaConvert_Default_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "apigateway_invoke_full_access" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}

resource "aws_iam_role_policy_attachment" "mediaconvert_full_access_to_lambda" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElementalMediaConvertFullAccess"
}
