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

resource "aws_iam_role" "iam_for_lambda" {
  name = "mediaconverteda-role"

  assume_role_policy = jsonencode(
    { "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
        }
      ]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "crcvisitorcount-policy"
  path        = "/"
  description = "AWS IAM Policy for Lambda"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
      ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}
