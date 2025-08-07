output "iam_user_names" {
  value = [for user in aws_iam_user.users : user.name]
}

output "data_engineers_group" {
  value = aws_iam_group.data_engineers.name
}


