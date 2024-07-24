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