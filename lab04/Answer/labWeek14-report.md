# Lab 4 — Plan/Apply Lifecycle และ Terraform State

## Step 0 — Addresses

`terraform state list` หลัง apply:

```
data.aws_vpc.default
module.vpc.aws_default_network_acl.this[0]
module.vpc.aws_default_route_table.default[0]
module.vpc.aws_default_security_group.this[0]
module.vpc.aws_internet_gateway.this[0]
module.vpc.aws_route.public_internet_gateway[0]
module.vpc.aws_route_table.public[0]
module.vpc.aws_route_table_association.public[0]
module.vpc.aws_route_table_association.public[1]
module.vpc.aws_subnet.public[0]
module.vpc.aws_subnet.public[1]
module.vpc.aws_vpc.this[0]
module.web_server.data.aws_ami.amazon_linux
module.web_server.aws_instance.server["api"]
module.web_server.aws_instance.server["web"]
module.web_server.aws_security_group.web
```

## Part 1 — Dependency Graph

ไฟล์: `graph.dot`, `graph.svg`, `graph.png`, `graph-plan.svg`

edge ของ `module.web_server` (`evidence/part1-web-server-edges.txt`):

```
"module.web_server.aws_instance.server" -> "module.vpc.aws_subnet.public";
"module.web_server.aws_instance.server" -> "module.web_server.data.aws_ami.amazon_linux";
"module.web_server.aws_instance.server" -> "module.web_server.aws_security_group.web";
"module.web_server.aws_security_group.web" -> "module.vpc.aws_vpc.this";
```

### Checkpoint 1

| | `graph.svg` (config) | `graph-plan.svg` (`-plan=tfplan`) |
|---|---|---|
| nodes / edges | 88 / 119 | 541 / 1121 |

ความต่าง: `graph.svg` เป็น graph ระดับ resource block แบบย่อ (เช่น `aws_instance.server` เป็น node เดียว) ส่วน `graph-plan.svg` เป็น graph แบบ `-type=apply` ของงานใน plan ที่บันทึกไว้ มีทุก node ที่ Terraform ต้องเดินจริง ทั้ง variable, local, output, provider และ node `(expand)` ของ module/for_each จึงใหญ่กว่ามาก

### คำถาม 1

node ที่ไม่มี dependency (ไม่มีลูกศรชี้ออกไปหา node อื่น) ได้แก่ `module.web_server.data.aws_ami.amazon_linux`, `module.vpc.aws_vpc.this`, `data.aws_vpc.default`, `module.vpc.data.aws_region.current`, `module.vpc.data.aws_partition.current`, `module.vpc.data.aws_caller_identity.current` ฯลฯ Terraform เริ่มทำ node เหล่านี้ได้ทันทีพร้อมกัน AMI data source อยู่ในกลุ่มนี้เพราะ argument ทั้งหมดเป็นค่าคงที่ (`owners`, `filter`) ไม่ได้อ้าง resource ใด ต้องการแค่ provider ก็ query ได้เลย

### คำถาม 2

`module.web_server.data.aws_ami.amazon_linux` → `module.web_server.aws_instance.server["web"]` เป็น edge ตรง ไม่มี node อื่นคั่น เพราะ `ami = data.aws_ami.amazon_linux.id` (instance ยังขึ้นกับ security group และ subnet แต่นั่นเป็นอีกเส้นทางหนึ่ง)

### คำถาม 3

ตัวอย่าง: `module.web_server.data.aws_ami.amazon_linux` กับ `module.vpc.aws_vpc.this` หรือ `aws_instance.server["web"]` กับ `aws_instance.server["api"]` ไม่มี edge ระหว่างกัน Terraform จึงทำพร้อมกันได้ (ค่า default `-parallelism=10`) เวลา apply รวมจึงใกล้เคียงเส้นทางที่ยาวที่สุดใน graph ไม่ใช่ผลรวมเวลาของทุก resource — EC2 ใช้เวลาสร้างหลายสิบวินาที การสร้าง 2 เครื่องพร้อมกันช่วยประหยัดเวลาได้ชัด

### คำถาม 4

edge มาจากค่าที่ส่งเข้า module: root `main.tf` ส่ง `vpc_id = module.vpc.vpc_id` เข้า `module.web_server` แล้วใน module `aws_security_group.web` ใช้ `vpc_id = var.vpc_id` Terraform ไล่ reference ข้ามขอบ module ได้ (`var.vpc_id` → `module.vpc.vpc_id` output → `aws_vpc.this`) จึงเกิด edge `aws_security_group.web -> module.vpc.aws_vpc.this` ทั้งที่ child module ไม่รู้จักชื่อ `module.vpc`

## Part 2 — Plan Files

- `terraform plan -out=tfplan` → `Plan: 14 to add, 0 to change, 0 to destroy.` ไฟล์ `tfplan` ขนาด 30K เป็น binary (zip)
- `terraform show -json tfplan | jq ...` (`evidence/part2-plan-actions.txt`) — ทุก address มี action `["create"]`
- `terraform apply tfplan` → apply ทันทีโดยไม่ถาม `yes`

### Checkpoint 2

1. สร้าง `tfplan2` (`No changes`) แล้วแก้ `Owner` ใน `locals.tf` เป็น `IPA-Student-Lab4` จากนั้น `terraform apply tfplan2` → **Terraform apply แผนเดิม** (ไม่มีการเปลี่ยนแปลง) โดยไม่สนใจ config ที่แก้ภายหลัง เพราะ plan file เก็บ snapshot ของ config ไว้แล้ว และ state ยังไม่เปลี่ยน
2. เพื่อพิสูจน์ staleness: สร้าง `tfplan3` แล้ว apply การแก้ tag ปกติ (`0 added, 11 changed`) ทำให้ state เปลี่ยน จากนั้น `terraform apply tfplan3`:

```
Error: Saved plan is stale

The given plan file can no longer be applied because the state was changed by
another operation after the plan was created.
```

**Terraform ปฏิเสธ** เมื่อ state เปลี่ยนหลังสร้างแผน (ตรวจจาก lineage + serial ของ state ที่บันทึกใน plan)

### คำถาม 5

plan คือ diff ระหว่าง config กับ state ณ เวลาหนึ่ง ถ้า state เปลี่ยนแล้ว diff นั้นไม่ได้อธิบายการเปลี่ยนจาก "ของจริงตอนนี้" อีกต่อไป หาก apply ต่อไปอาจย้อนการเปลี่ยนแปลงที่คนอื่นเพิ่ง apply สร้าง resource ซ้ำ หรือลบสิ่งที่ไม่ควรลบ และสิ่งที่เกิดจริงจะไม่ใช่สิ่งที่ reviewer อนุมัติ — ซึ่งทำลายหลักของ CI/CD "plan ใน PR แล้ว apply artefact เดียวกันตอน merge"

## Part 3 — Planning Modes & Targeting

### Checkpoint 3

ก่อนมี drift: `terraform plan -refresh-only` → `No changes. Your infrastructure still matches the configuration.`

เพิ่ม tag `ManualChange = true` ให้ instance `web` (`i-0342c76a184f75c86`) นอก Terraform (ใช้ `aws ec2 create-tags` แทนการคลิกใน Console — ผลต่อ AWS เหมือนกัน)

`terraform plan -refresh-only` (`evidence/part3-refresh-only-drift.txt`):

```
Note: Objects have changed outside of Terraform
  # module.web_server.aws_instance.server["web"] has changed
  ~ resource "aws_instance" "server" {
      ~ tags = {
          + "ManualChange" = "true"
...
This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were to apply this plan, Terraform would update the Terraform
state to reflect these detected changes.
```

`terraform plan` (`evidence/part3-plan-drift.txt`):

```
  ~ update in-place
          - "ManualChange" = "true" -> null
Plan: 0 to add, 1 to change, 0 to destroy.
```

ความต่าง: `-refresh-only` แค่ **รายงาน drift** และเสนอให้บันทึกค่าจริงเข้า state (ยอมรับ drift) โดยไม่แตะ AWS ส่วน plan ปกติถือ config เป็นความจริง และเสนอ **แก้ AWS ให้กลับมาตรง config** คือลบ tag `ManualChange` ทิ้ง

### Destroy mode

`terraform plan -destroy` → `Plan: 0 to add, 0 to change, 14 to destroy.`

### คำถาม 6

จาก graph: `aws_instance.server -> aws_security_group.web -> module.vpc.aws_vpc.this` ตอนลบ Terraform เดิน graph กลับด้าน instance ต้องหายไปก่อน เพราะ AWS ไม่ให้ลบ security group ที่ยังผูกกับ network interface ของ instance (`DependencyViolation`) และ security group ต้องหายก่อน VPC เพราะ AWS ไม่ให้ลบ VPC ที่ยังมี security group (ที่ไม่ใช่ default) subnet หรือ IGW อยู่

### Targeting (`evidence/part3-target-*.txt`)

| คำสั่ง | ผล |
|---|---|
| `-target='module.web_server.aws_security_group.web'` | No changes |
| `-target='module.web_server'` | `Plan: 0 to add, 1 to change` (ลบ tag drift ของ instance web) |
| `-target='module.vpc'` | No changes |

drift อยู่ที่ instance จึงเห็นเฉพาะเมื่อ target ครอบ instance — target แค่ security group จะ "มองไม่เห็น" drift นั้นเลย

### คำถาม 7

1. plan ที่ได้ไม่ครบ: Terraform ทำเฉพาะ target และ dependency ของมัน การเปลี่ยนแปลงอื่นที่รออยู่ (เช่น drift ข้างบน หรือ resource ที่ขึ้นกับ target) ถูกข้ามแบบเงียบ ๆ ทำให้ state กับ config ไม่ตรงกันสะสมไปเรื่อย ๆ
2. ไม่ผ่านการตรวจทั้งระบบ: ไม่มีใครเห็นภาพรวม เกิด config ที่ "apply ได้เป็นส่วน ๆ" แต่ apply ทั้งชุดไม่ผ่าน หรือได้ผลต่างออกไป และขัดกับ workflow ที่ plan ทั้งหมดต้องว่างเปล่าหลัง apply

### Checkpoint 4 — Replace

- `terraform plan -replace='module.web_server.aws_instance.server["web"]'` → `will be replaced, as requested` / `Plan: 1 to add, 0 to change, 1 to destroy.`
- `terraform apply -replace=...` → `Apply complete! Resources: 1 added, 0 changed, 1 destroyed.`
- instance ID: `i-0342c76a184f75c86` → `i-03c91a5fb3578d04c`

`diff` ของ `terraform output` ก่อน/หลัง:

```
<   "10.0.1.223",
>   "10.0.1.114",
<   "web" = "ec2-34-205-81-107.compute-1.amazonaws.com"
>   "web" = "ec2-3-239-230-55.compute-1.amazonaws.com"
```

ทั้ง `all_private_ips` และ `server_summary` เปลี่ยนเฉพาะ `web` ส่วน `api` เหมือนเดิม

### Refresh timing (`evidence/part3-timing.txt`)

| คำสั่ง | real |
|---|---|
| `terraform plan` | 19.5 s |
| `terraform plan -refresh=false` | 8.1 s |

### คำถาม 8

`-refresh=false` ไม่เรียก API ไปอ่านสถานะจริง จึงเร็วกว่า ~2.4 เท่า แต่ plan อ้าง state ที่อาจเก่า: drift (เช่น `ManualChange`) หรือ resource ที่ถูกลบนอก Terraform จะมองไม่เห็น plan อาจบอก "No changes" ทั้งที่ของจริงไม่ตรง หรือ apply แล้ว error กลางทาง ใช้ได้เมื่อมั่นใจว่าไม่มีใครแตะ infrastructure และต้องการ iterate config เร็ว ๆ เท่านั้น

## Part 4 — Variable Precedence

### Checkpoint 5 (`evidence/part4-precedence.txt`)

| Rank | Source | Value observed |
|---|---|---|
| 1 (lowest) | `default` ใน `variables.tf` | `"from-default"` |
| 2 | env `TF_VAR_precedence_demo` | `"from-env-var"` |
| 3 | `terraform.tfvars` (auto-load) | `"from-tfvars-file"` |
| 4 | `-var-file=custom.tfvars` | `"from-custom-file"` |
| 5 (highest) | `-var="precedence_demo=from-cli"` | `"from-cli"` |

การทดสอบจัดให้แต่ละขั้นมีแหล่งที่ต่ำกว่าเปิดอยู่ด้วย: ขั้น 3 ตั้ง `TF_VAR_...` ไว้ แต่ `terraform.tfvars` ชนะ และขั้น 5 ตั้ง env + มี `terraform.tfvars` + `-var-file` แต่ `-var` ยังชนะ จึงยืนยันลำดับได้จริง ไม่ใช่แค่ดูทีละแหล่ง ลบ `terraform.tfvars` / `custom.tfvars` และไม่ได้ export env ค้างไว้หลังทดสอบ

### คำถาม 9

1. ค่าที่พิมพ์บน command line ถูกเก็บใน shell history (`~/.bash_history`) และ log ของ CI ที่ echo คำสั่ง
2. argument ของ process มองเห็นได้โดยผู้ใช้อื่นบนเครื่องเดียวกันผ่าน `ps` / `/proc/<pid>/cmdline` ระหว่างที่ Terraform รัน

ควรส่ง secret ผ่าน secret manager, `TF_VAR_` จาก secret store ของ CI หรือ data source แทน

## Part 5 — State

### Checkpoint 6 (`evidence/part5-state-summary.txt`)

```
["check_results","lineage","outputs","resources","serial","terraform_version","version"]
version           = 4
terraform_version = "1.16.3"
serial            = 64
lineage           = "df663a48-d7f0-5346-f391-d8f81fb3ed09"
.resources | length = 13   (instance objects รวม 16)
```

block ที่เราเขียนเองมี 6 อัน — ใน root 3 (`module "vpc"`, `module "web_server"`, `data "aws_vpc" "default"`) และใน `modules/web-server` 3 (data AMI, security group, instance) โดยมีแค่ 4 อันที่เป็น resource/data จริง (`data.aws_vpc.default`, data AMI, security group, instance) แต่ state มี 13 resource entry / 16 instance เพราะ VPC registry module สร้างเองอีก 11 ตัว และ `aws_instance.server` เป็น 1 entry ที่มี 2 instance

### Serial (`evidence/part5-serial.txt`)

แก้ `Owner` เป็น `IPA-Student-Lab4b` แล้ว `terraform apply -auto-approve` (`0 added, 11 changed`):

```
serial before=64 after=76
```

serial เพิ่ม 12 ใน apply เดียว เพราะ Terraform บันทึก state เป็นระยะ ๆ ระหว่าง apply (ทุกครั้งที่ resource เสร็จ) ไม่ใช่ครั้งเดียวตอนจบ

### คำถาม 10

- `serial` — เลข revision ที่เพิ่มทุกครั้งที่เขียน state ใช้บอกว่า state ไหนใหม่กว่า ป้องกันการเขียน state เก่าทับ state ใหม่ และใช้ตรวจ plan stale (Part 2)
- `lineage` — UUID ที่สร้างตอน state ถูกสร้างครั้งแรก และคงที่ตลอดอายุ ใช้ระบุว่า state สองไฟล์เป็น "สายเดียวกัน" หรือไม่
- ถ้า lineage ไม่ตรง แปลว่าเป็น state ของ infrastructure คนละชุด (เช่น copy ผิดโฟลเดอร์/ผิด workspace) การเขียนทับจะทำให้ Terraform ลืม resource จริงทั้งหมดของชุดเดิม (orphan) และอาจสร้างซ้ำ/ลบผิด จึงปฏิเสธแม้ serial จะสูงกว่า

### Step 5.3 (`evidence/part5-instance-jq.txt`)

```
{"module":"module.web_server","mode":"managed","type":"aws_instance","name":"server","instances":2}
index_key ของแต่ละ instance: ["api","web"]
```

### คำถาม 11

`aws_instance.server` มี 1 entry เพราะ state เก็บต่อ resource block และเก็บแต่ละ instance ใน `instances[]` `index_key` เก็บ **key ของ map** จาก `for_each` คือ `"api"` และ `"web"` (string) ถ้าใช้ `count` จะเป็นตัวเลข `0`, `1` ซึ่งผูกกับตำแหน่ง — ถ้าลบรายการแรกออก ตัวที่เหลือจะเลื่อน index ทำให้ Terraform replace instance ที่ไม่ได้ตั้งใจแตะ ส่วน `for_each` ผูกกับชื่อ ลบ `api` ก็กระทบแค่ `api`

### Checkpoint 7 (`evidence/part5-outputs-admin.txt`)

```
terraform output        →  admin_password = <sensitive>
jq '.outputs.admin_password' terraform.tfstate
{
  "value": "ChangeMe123!",
  "type": "string",
  "sensitive": true
}
```

**ไม่เข้ารหัส และไม่ obfuscate เลย** — เป็น plaintext ใน JSON `sensitive = true` มีผลแค่การแสดงผลใน CLI/plan ใครอ่านไฟล์ state ได้ก็อ่าน secret ได้ (และ `terraform output -raw admin_password` ก็แสดงค่าได้)

### คำถาม 12

1. **Security** — เข้ารหัส at rest และ in transit, จำกัดสิทธิ์อ่าน/เขียนด้วย IAM/RBAC เพราะ state มี secret แบบ plaintext
2. **Resiliency** — versioning/backup กู้คืนได้เมื่อ state เสียหายหรือถูกลบ (เช่น S3 versioning)
3. **Availability + locking** — ทีมและ CI เข้าถึงได้ตลอด พร้อม state locking (เช่น S3 lockfile / DynamoDB) ป้องกันสอง apply เขียนพร้อมกัน

### คำถาม 13 (`terraform_version = "1.16.3"`)

Terraform ที่เก่ากว่าเวอร์ชันที่เขียน state จะปฏิเสธการทำงานกับ state นั้น (state ระบุว่าเขียนโดยเวอร์ชันที่ใหม่กว่า ให้ upgrade) เป็นทางเดียวเพราะเวอร์ชันใหม่รู้จักรูปแบบเก่าและ upgrade ได้ แต่เวอร์ชันเก่าไม่รู้ว่าเวอร์ชันใหม่อาจเพิ่ม field/ความหมายอะไร ถ้าอ่านแล้วเขียนกลับอาจทำข้อมูลหาย ทีมจึงควร pin `required_version` ให้ตรงกัน

### Step 5.6

`cp terraform.tfstate terraform.tfstate.lab4-backup` — เก็บไว้ใช้ Lab 5 (snapshot ตอนที่ infrastructure ยังอยู่, serial 76)

## Part 6 — Pitfalls (B และ D)

### Checkpoint 8 — Pitfall B: Always-detected change

**Error/output** — เพิ่ม `LastPlanned = timestamp()` ใน `local.common_tags`, `terraform apply` แล้ว `terraform plan` สองครั้ง:

```
evidence/pitB-plan1.txt: Plan: 0 to add, 11 to change, 0 to destroy.
evidence/pitB-plan2.txt: Plan: 0 to add, 11 to change, 0 to destroy.
          - "Environment" = "dev"
          - "LastPlanned" = "2026-11-04T16:40:04Z"
          - "ManagedBy"   = "Terraform"
          ...
```

(ทั้ง map `tags` กลายเป็น `(known after apply)` เพราะมีสมาชิกหนึ่งตัวที่ยังไม่รู้ค่า plan จึงแสดงค่าเก่าทั้งชุดเป็น `-`)

**Diagnosis** — Terraform เทียบค่า tags ใน state (เวลาตอน apply ครั้งก่อน) กับค่าที่ config ประเมินได้ตอนนี้ `timestamp()` เป็นฟังก์ชัน impure: คืนค่าต่างกันทุกครั้งที่ประเมิน และค่าจริงรู้ตอน apply เท่านั้น (`known after apply`) ต่างจากฟังก์ชันใน Lab 3 (`merge`, `for`, `contains`, `regex`) ที่เป็น pure ได้ผลเดิมเมื่อ input เดิม ค่าจึงไม่มีวันตรงกับ state และเพราะ tag อยู่ใน local ที่ทุก resource ใช้ resource ที่มี tags ทั้ง 11 ตัวจึงมี diff ทุก plan

**Fix 1** — `lifecycle { ignore_changes = [tags["LastPlanned"]] }` บน `aws_instance.server` → `Plan: 0 to add, 9 to change` (`evidence/pitB-fix1-plan.txt`) แก้ได้แค่ instance 2 ตัว resource ใน `module.vpc` อีก 8 ตัวและ security group ยังมี diff และเราแก้ lifecycle ของ registry module ไม่ได้ด้วย

**Fix 2 (ที่เลือก ship)** — ลบบรรทัด `LastPlanned` ออก → apply แล้ว `terraform plan` = `No changes. Your infrastructure matches the configuration.` (`evidence/pitB-fix2-plan.txt`) ค่าที่เปลี่ยนทุกครั้งไม่ควรอยู่ใน config ถ้าต้องการเวลา deploy ให้เก็บใน state ด้วย `time_static` (Lab 5) — ดู `pitfalls/always-detected-change.md`

### Checkpoint 8 — Pitfall D: Hidden dependency

**Error/output** — `aws_dynamodb_table_item.seed` ใช้ `table_name = "${local.name_prefix}-demo"` แบบ hard-code (`evidence/pitD-apply-broken.txt`):

```
aws_dynamodb_table_item.seed: Creating...
aws_dynamodb_table.demo: Creating...
aws_dynamodb_table.demo: Creation complete after 14s [id=ipa-lab04-dev-demo]
Error: creating DynamoDB Table (ipa-lab04-dev-demo) Item: operation error DynamoDB:
PutItem, https response error StatusCode: 400, ... ResourceNotFoundException:
Requested resource not found
```

`terraform graph` (`evidence/pitD-graph-broken.txt`): `(no edge between seed and demo)`

**Diagnosis** — Terraform สร้าง dependency จาก reference ใน expression เท่านั้น string ที่ประกอบจาก `local.name_prefix` ทำให้ seed ขึ้นกับ local ไม่ใช่ table ใน graph สองตัวนี้จึงเป็น node อิสระที่เริ่มพร้อมกันได้ — รอบนี้ seed เริ่ม `PutItem` ก่อน table มีอยู่จึงล้ม รอบหน้าอาจผ่านถ้า scheduler บังเอิญเริ่ม table ก่อนและ table พร้อมทัน การผ่านครั้งเดียวจึงไม่ได้พิสูจน์อะไร เพราะลำดับไม่ได้ถูกบังคับ เป็น race condition ที่ขึ้นกับจังหวะ/latency ของ API

**Fix 1 — `depends_on = [aws_dynamodb_table.demo]`**: graph มี `"aws_dynamodb_table_item.seed" -> "aws_dynamodb_table.demo"`, table สร้างเสร็จ (14–15s) ก่อน seed เริ่ม, `Apply complete! Resources: 2 added`

**Fix 2 — `table_name = aws_dynamodb_table.demo.name` (ที่เลือก)**: edge เดียวกัน, `Apply complete! Resources: 2 added`

เลือก Fix 2 เพราะ dependency เกิดจากข้อมูลจริงที่ใช้ ชื่อมีแหล่งเดียว (ถ้าแก้ชื่อ table ค่าใน item ตามไปเอง) ส่วน `depends_on` เป็นลำดับที่ต้องดูแลด้วยมือ ยังมีชื่อซ้ำสองที่ที่อาจไม่ตรงกันภายหลัง และทำให้ plan ระมัดระวังเกินจำเป็น ควรเก็บ `depends_on` ไว้สำหรับ dependency ที่ไม่มีทาง express ด้วย reference — ดู `pitfalls/hidden-dependency.tf.example` และ `pitfalls/hidden-dependency-depends-on.tf.example`

ทดลองเสร็จลบ resource DynamoDB ด้วย `terraform destroy -target` และเอา block ออกจาก `main.tf` แล้ว

หมายเหตุ: ทำ Pitfall D ขณะที่ VPC/EC2 ยังอยู่ (ไม่ได้ destroy ก่อน) เพราะสอง resource นี้ไม่เกี่ยวกับ infrastructure เดิม และ table ยังไม่มีอยู่ใน state/AWS จึงเริ่มจากศูนย์สำหรับคู่นี้เหมือนกัน

## Part 7 — Clean Up

```
terraform destroy  →  Destroy complete! Resources: 14 destroyed.
terraform state list  →  (ว่าง)
grep -rn 'access_key\|secret_key' . --include='*.tf'  →  ไม่พบ
aws ec2 describe-instances (tag Project=ipa-lab04, ยังไม่ terminate)  →  ไม่มี
```

credential อยู่ใน `~/.aws/credentials` เท่านั้น ไม่อยู่ในไฟล์ `.tf` ใด ๆ `.gitignore` ครอบ `*.tfstate`, `*.tfstate.*`, `terraform.tfvars`, `custom.tfvars`, `.terraform/` และ graph output แล้ว ลบ `tfplan*` ทิ้ง
