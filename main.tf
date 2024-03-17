terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
#Provider change to us-east-1
provider "aws" {
  region = "us-east-1"
}

#Variable to hold bucket_names
variable "s3_bucket_names" {
  type = list
  default = ["medium-non-resize2","medium-resize-2"]
}

#Create two s3 buckets, one for ingest, one for resize
resource "aws_s3_bucket" "image-buckets" {
  count = length(var.s3_bucket_names)
  bucket = var.s3_bucket_names[count.index]
  force_destroy = true
}

#Create sns topic 
resource "aws_sns_topic" "resize_topic2" {
  name = "image-resize-topic2"
}

#Create topic email subscription
resource "aws_sns_topic_subscription" "resize_sub2" {
  topic_arn = aws_sns_topic.resize_topic2.arn
  protocol = "email"
  endpoint = "loeweps@gmail.com"
}

#Add lambda service assume role policy
data "aws_iam_policy_document" "lambda_assume_role_policy"{
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {  
  name = "lambda-image-role"  
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "archive_file" "python_lambda_package" {  
  type = "zip"  
  source_file = "./code/resize_function.py" 
  output_path = "resize_function.zip"
}

resource "aws_lambda_function" "test_lambda_function" {
        function_name = "lambda_resize"
        filename      = "resize_function.zip"
        source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
        role          = aws_iam_role.lambda_role.arn
        runtime       = "python3.9"
        handler       = "lambda_function.lambda_handler"
        timeout       = 10
        layers        = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"]
}

resource "aws_iam_policy" "lamdba_image_policy2" {
  name        = "image-policy2"
  description = "Lambda policy actions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "sns:*",
          "lambda:GetLayerVersion"
        ]
        Resource = "*"
      },
    ]
  })
}

#Attach policy
resource "aws_iam_policy_attachment" "image_policy_attach" {
  name = "image_policy_attachment"
  policy_arn = aws_iam_policy.lamdba_image_policy2.arn
  roles = [aws_iam_role.lambda_role.arn]
}

# Adding S3 bucket as trigger to my lambda and giving the permissions
resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = "medium-non-resize2"
  lambda_function {
    lambda_function_arn = "${aws_lambda_function.test_lambda_function.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}