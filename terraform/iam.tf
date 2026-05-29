# SSM Session Manager — EC2 콘솔 → 연결 → Session Manager 탭에서 키 없이 접속 가능
resource "aws_iam_role" "ssm" {
  name = "ThreeTier-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-SSM-Role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "ThreeTier-SSM-InstanceProfile"
  role = aws_iam_role.ssm.name
}
