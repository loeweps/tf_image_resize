output "sns_topic_arn" {
  value = aws_sns_topic.resize_topic2.arn
}

output "sns_topic_subscription_arn" {
  value = aws_sns_topic_subscription.resize_sub2.arn
}