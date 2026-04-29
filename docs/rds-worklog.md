# RDS Worklog

## 2026-04-29

### Summary

- Created PostgreSQL RDS instance for team4.
- Reused existing shared DB subnet group: `eks-vpc-shared-rds-subnets`.
- Created RDS-only security group: `sg-00d26e3d742f4eeb1`.
- Allowed PostgreSQL access from the active team4 EKS node security group: `sg-06abf01dd54907a21`.
- Created PostgreSQL parameter group `fairline-dev-postgres` with logical replication enabled for future CDC.
- Drafted and committed service-owned schema and business table DDL for the shared RDS model.

### RDS Connection

- Endpoint: `fairline-dev-postgres.c90c2ii6yx10.ap-northeast-2.rds.amazonaws.com`
- Port: `5432`
- Database: `concert`
- Username: `fairline_admin`
- JDBC URL: `jdbc:postgresql://fairline-dev-postgres.c90c2ii6yx10.ap-northeast-2.rds.amazonaws.com:5432/concert`

### Terraform Footprint

- RDS bootstrap stack: [terraform/fairline/main.tf](/Users/jihyunpark/Desktop/fairline-k8s/terraform/fairline/main.tf:1)
- Applied variables: [terraform/fairline/terraform.tfvars](/Users/jihyunpark/Desktop/fairline-k8s/terraform/fairline/terraform.tfvars:1)

### Schema Design Decision

- Keep a single RDS instance for now.
- Split ownership by PostgreSQL schema:
  - `auth`
  - `concert`
  - `ticketing`
  - `payment`
  - `queue`
- Delay Outbox tables until the business tables are settled.

### Source Of Truth Used For Table Design

Because `fairline-k8s` only contains Kubernetes manifests, the business table draft was derived from the adjacent service source code:

- User model: [User.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/users/User.java:1>)
- Concert queries: [ConcertQueryRepository.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/concerts/repository/ConcertQueryRepository.java:1>)
- Seat model and queries: [Seat.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/seats/domain/Seat.java:1>), [SeatRepository.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/seats/repository/SeatRepository.java:1>)
- Booking model: [Booking.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/bookings/domain/Booking.java:1>), [BookingItem.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/bookings/domain/BookingItem.java:1>)
- Payment model: [Payment.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/Payment.java:1>), [Refund.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/Refund.java:1>), [PaymentEvent.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/PaymentEvent.java:1>)
- Queue fan score model: [UserArtistFanScore.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/backend/src/main/java/com/example/SKALA_Mini_Project_1/modules/fanscore/UserArtistFanScore.java:1>)

### DDL Files Added

- Main schema bootstrap: [sql/rds/001_service_schemas.sql](/Users/jihyunpark/Desktop/fairline-k8s/sql/rds/001_service_schemas.sql:1)
- Verification query set: [sql/rds/002_verify_service_schemas.sql](/Users/jihyunpark/Desktop/fairline-k8s/sql/rds/002_verify_service_schemas.sql:1)

### Applied To RDS

- Applied from the in-cluster `postgres` Pod because the RDS endpoint is private and not reachable directly from the local workstation.
- Verified live connection target:
  - database: `concert`
  - server IP: `10.0.150.71`
  - port: `5432`

### Created Schemas

- `auth`
- `concert`
- `ticketing`
- `payment`
- `queue`

### Created Business Tables

- `auth.users`
- `concert.artist`
- `concert.concerts`
- `concert.schedules`
- `concert.seats`
- `ticketing.bookings`
- `ticketing.booking_items`
- `payment.payments`
- `payment.refunds`
- `payment.payment_events`
- `queue.user_artist_fan_scores`

### Important Follow-up

The current Kubernetes config still uses one shared `DB_URL` for every service:

- [configmap.yaml](/Users/jihyunpark/Desktop/fairline-k8s/configmap.yaml:7)

That means the apps will not automatically use the new service-owned schemas yet. The next app-connection step must do one of the following:

- give each service its own JDBC URL with `currentSchema=<service_schema>`
- or set Hibernate / datasource default schema per service
- or qualify every SQL table name explicitly

Without that change, the services will keep looking in `public`.

### Open Items

- Apply the prepared Kubernetes manifest changes that repoint each service to RDS with a service-specific schema search path.
- Verify each service starts successfully against RDS after rollout.
- Add `outbox_event` tables per schema.
- Provision Kafka and Debezium after the DB layout is fixed.

### Prepared Kubernetes Routing

The repository now contains manifest-level routing for the shared RDS database:

- shared base JDBC URL in [configmap.yaml](/Users/jihyunpark/Desktop/fairline-k8s/configmap.yaml:7)
- RDS credentials in [secret.yaml](/Users/jihyunpark/Desktop/fairline-k8s/secret.yaml:8)
- service-specific `DB_URL` overrides in:
  - [user-auth-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/user-auth-service/deployment.yaml:32)
  - [concert-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/concert-service/deployment.yaml:32)
  - [ticketing-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/ticketing-service/deployment.yaml:32)
  - [payment-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/payment-service/deployment.yaml:32)
  - [queue-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/queue-service/deployment.yaml:32)

These use PostgreSQL JDBC `currentSchema` as a schema search path, not a single-schema lock:

- `user-auth-service`: `auth,queue,concert,ticketing,payment,public`
- `concert-service`: `concert,public`
- `ticketing-service`: `ticketing,concert,public`
- `payment-service`: `payment,ticketing,concert,queue,auth,public`
- `queue-service`: `queue,concert,ticketing,payment,auth,public`

This was chosen because several services read across multiple business schemas through shared-kernel repositories and fan-score synchronization logic.

Because the current RDS instance is small, the manifests also cap each service's Hikari pool to a low default during migration:

- `SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=3`
- `SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE=1`

This avoids exhausting PostgreSQL connection slots during rolling updates while multiple old and new Pods overlap.
