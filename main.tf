resource "aws_s3_bucket" "cattube-source" {
  bucket = "cattube-source1912"
}

resource "aws_s3_bucket" "cattube-destination" {
  bucket = "cattube-destination1912"
}

resource "aws_media_convert_queue" "eda-converter" {
  name = "catqueue"
}

data "archive_file" "ziplambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/function.zip"
}

data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "assume_role_mediaconvert" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["mediaconvert.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_mediaconvert" {
  name               = "MediaConvert_Default_Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_mediaconvert.json
}

resource "aws_iam_role_policy_attachment" "mediaconvert_s3_policy" {
  role       = aws_iam_role.iam_for_mediaconvert.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "mediaconvert_apigateway_policy" {
  role       = aws_iam_role.iam_for_mediaconvert.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_mediaconvert_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElementalMediaConvertFullAccess"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cattube_converter_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cattube-source.arn
}

resource "aws_lambda_function" "cattube_converter_function" {
  filename         = data.archive_file.ziplambda.output_path
  source_code_hash = data.archive_file.ziplambda.output_base64sha256
  function_name    = "cattube_converter_function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.9"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.cattube-source.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cattube_converter_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_sns_topic" "output_notifications" {
  name = "output-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.output_notifications.arn
  protocol  = "email"
  endpoint  = "b.labigalini@gmail.com" # Your e-mail goes here :D
}

resource "aws_sns_topic_policy" "output_notifications_policy" {
  arn = aws_sns_topic.output_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.output_notifications.arn,
        Condition = {
          ArnLike = {
            "AWS:SourceArn" : aws_s3_bucket.cattube-destination.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "cattube-destination-notification" {
  bucket = aws_s3_bucket.cattube-destination.id

  topic {
    topic_arn = aws_sns_topic.output_notifications.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic.output_notifications, aws_sns_topic_policy.output_notifications_policy]
}