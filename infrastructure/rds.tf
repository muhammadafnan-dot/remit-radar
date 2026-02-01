resource "aws_db_subnet_group" "main" {
    name = "${var.project_name}-db-subnet"
    subnet_ids = [
        aws_subnet.private_a.id,
        aws_subnet.private_b.id,
    ]
}

resource "aws_db_instance" "postgres" {
    identifier = "${var.project_name}-db"
    engine = "postgres"
    engine_version = "16"
    instance_class = "db.t3.micro"

    allocated_storage     = 20         # 20 GB
    max_allocated_storage = 50         # Auto-scale up to 50 GB

    db_name  = "remit_radar_production"
    username = var.db_username
    password = var.db_password

    db_subnet_group_name   = aws_db_subnet_group.main.name
    vpc_security_group_ids = [aws_security_group.rds.id]

    skip_final_snapshot       = false
    final_snapshot_identifier = "${var.project_name}-final-snapshot"

    backup_retention_period = 7        # Keep 7 days of automatic backups

    tags = { Name = "${var.project_name}-db" }
}