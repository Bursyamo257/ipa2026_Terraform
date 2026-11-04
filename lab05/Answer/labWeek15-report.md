# Lab 5 — Remote State และ State Management

## Part 1 — Remote Backend

**Checkpoint 1:** สร้าง bucket `ipa-tfstate-58b11137` ด้วย AWS CLI แล้วใช้ Terraform จัดการ configuration ของ bucket

```
aws_s3_bucket_public_access_block.state
aws_s3_bucket_server_side_encryption_configuration.state
aws_s3_bucket_versioning.state
```

**คำถาม 1**
- Versioning ตอบเรื่อง **Resiliency** เพราะย้อนกลับไป state เวอร์ชันก่อนได้เมื่อไฟล์เสียหายหรือถูกเขียนทับ
- Encryption ตอบเรื่อง **Security** เพราะเข้ารหัส state ขณะจัดเก็บ ซึ่งจำเป็นเนื่องจาก state เก็บ secret เป็น plaintext
- Public access block ตอบเรื่อง **Security** เพราะกันไม่ให้ bucket กลายเป็น public
- ข้อที่ไฟล์นี้ไม่ได้จัดการคือ **Availability** ซึ่งได้จากตัว S3 เอง และทำ cross-region replication เพิ่มได้ ส่วนการกันเขียนพร้อมกันใช้ `use_lockfile` ใน backend block

**คำถาม 2:** bucket ไม่ได้อยู่ใน state ดังนั้น `terraform destroy` จะลบเฉพาะ configuration ทั้ง 3 ตัว ตัว bucket และข้อมูลข้างในยังอยู่ ผู้ที่สร้าง bucket จึงต้องลบเอง (ดู Part 5)

## Part 2 — Migrate State

ก่อน migrate ได้ apply แบบ local (14 resources) ได้ state ที่มี serial 15 และ lineage `ad77df5a…` จากนั้นเพิ่ม backend `s3` (`key = "lab05/terraform.tfstate"`, `use_lockfile = true`) แล้วรัน `terraform init -migrate-state`

**Checkpoint 2:**

```
cat terraform.tfstate          → (ว่าง)
aws s3 ls s3://.../lab05/      → terraform.tfstate  39693 bytes
S3 state                       → serial 1, lineage 5f71ec0e-…
terraform state list           → ครบ 16 รายการ
```

ไฟล์ local ว่างแล้ว แต่ `state list` ยังแสดง resource ครบ เพราะ Terraform อ่าน state จาก S3

**คำถาม 3:** lineage **ไม่ตรง**กับ Lab 4 (`df663a48…`) เนื่องจากตอนเริ่ม Lab 5 ได้ลบ state เดิมทิ้งแล้ว apply ใหม่ Terraform จึงสร้าง lineage ใหม่ให้ ข้อนี้แสดงว่า lineage ผูกกับไฟล์ state แต่ละชุด ไม่ได้ผูกกับ config ทั้งนี้ใน run นี้ state บน S3 ก็ได้ lineage ใหม่อีกชุดและ serial เริ่มที่ 1 แต่ resource ข้างในครบเหมือนเดิม และ plan หลัง migrate ได้ `No changes` สรุปได้ว่า migration เป็นการ copy เนื้อหา state ไปยัง backend ใหม่โดยไม่ได้แตะ infrastructure จริง

## Part 3 — State Locking

**Checkpoint 3:** ให้ Terminal 1 รัน `apply` แล้วค้างไว้ที่ prompt จากนั้นรัน `plan` ใน Terminal 2

```
Error: Error acquiring the state lock
... StatusCode: 412, api error PreconditionFailed
Lock Info:
  ID:        9276bc94-8a60-2db1-e6fd-089e232a8590
  Operation: OperationTypeApply
  Who:       ubuntu@ubuntu-VMware-Virtual-Platform
  Created:   2026-11-04 18:48:36 UTC
```

ระหว่างที่ lock อยู่ บน S3 มีไฟล์ `terraform.tfstate.tflock` (JSON ขนาด 250 bytes) เมื่อตอบ `no` ใน Terminal 1 ไฟล์นี้ก็หายไป

**คำถาม 4:** `force-unlock` ใช้เมื่อ process ที่ถือ lock ตายไปก่อนจะปล่อย lock เช่น CI ถูก kill หรือ network หลุด ทำให้ไฟล์ lock ค้างอยู่ ข้อควรระวังคือ ถ้า apply อีกตัวยังทำงานอยู่จริงแล้วเราปลด lock ทั้งสอง process จะแก้ infrastructure และเขียน state ทับกัน ผลคือ resource อาจถูกสร้างซ้ำ หลุดออกจาก state หรือ state เสียหาย

## Part 4 — Manipulating State

ก่อนเริ่มได้สำรอง state ด้วย `terraform state pull > backup-before-surgery.tfstate`

**Checkpoint 4:** เปลี่ยนชื่อ `module "web_server"` เป็น `module "web"` (ต้องรัน `terraform init` ใหม่ก่อน)

| | plan |
|---|---|
| ก่อน `state mv` | `3 to add, 0 to change, 3 to destroy` |
| หลัง `terraform state mv module.web_server module.web` | `No changes` |
| ใช้ `moved` block แทน | `has moved to …` / `0 to add, 0 to change, 0 to destroy` |

**คำถาม 5:** `moved` block อยู่ใน code จึงไปพร้อมกับ commit เมื่อเพื่อนในทีม pull branch ไปแล้ว plan ก็จะได้การย้ายเหมือนกันทุก environment และตรวจสอบได้ใน PR ส่วน `state mv` ต้องมีคนไปรันกับทุก state ด้วยมือ ถ้าเพื่อน plan ก่อนมีคนรัน จะเห็น destroy/create และอาจเผลอ apply ไป

**Checkpoint 5:** import ตาราง `ipa-adopted-18974` ได้ผลดังนี้

```
Plan:  1 to import, 0 to add, 1 to change, 0 to destroy
Apply: 1 imported, 0 added, 1 changed, 0 destroyed
terraform state show aws_dynamodb_table.adopted → name = "ipa-adopted-18974", billing_mode = "PAY_PER_REQUEST", hash_key = "id"
```

change 1 รายการมาจาก `default_tags` ของ provider ที่ต้องเพิ่ม tag ให้ตาราง ถ้าต้องการให้ import clean ควรใส่ tag เหล่านี้ตั้งแต่ตอนสร้างตาราง

**คำถาม 6:** ข้อดีของ `import` block เมื่อเทียบกับคำสั่ง `terraform import`
1. เห็นผลใน plan ก่อนที่จะเขียน state จริง
2. อยู่ใน code จึง review ผ่าน PR ได้ ใช้ใน CI ได้ และ import หลายรายการพร้อมกันหรือ generate config ให้อัตโนมัติได้

**State rm:** หลัง `terraform state rm aws_dynamodb_table.adopted` ตารางหายไปจาก state แต่ `aws dynamodb list-tables` ยังพบ `ipa-adopted-18974` จากนั้นจึงลบตารางด้วย CLI

**คำถาม 7:**
- กรณีที่ใช้ได้อย่างถูกต้อง: ย้าย resource ไปให้โปรเจกต์อื่นดูแล โดยทำ `state rm` ฝั่งเดิมแล้ว import ฝั่งใหม่ resource ไม่ต้องถูก destroy
- กรณีที่ทำให้เสียเงิน: resource ที่ถูก rm ออกจาก state แล้วยังรันอยู่ แต่ไม่มีใครเห็นใน plan หรือ destroy จึงถูกเก็บเงินไปเรื่อย ๆ

**Restore จาก backup:**

```
lab4-backup: serial 76, lineage df663a48-…, 13 resources
S3 ปัจจุบัน:   serial 6,  lineage 5f71ec0e-…, 13 resources
```

**คำถาม 8:** `state push` จะถูก**ปฏิเสธ** เพราะ lineage ไม่ตรงกัน Terraform มองว่าเป็น state คนละชุด และถ้า lineage ตรงกันแต่ serial ต่ำกว่าก็จะถูกปฏิเสธเช่นกัน การป้องกันนี้สำคัญ เพราะถ้า push ผ่าน Terraform จะลืม resource ของ lab05 ที่รันอยู่ทั้งหมด (กลายเป็น orphan) แล้วพยายามจัดการ resource เก่าของ Lab 4 ที่ไม่มีอยู่แล้ว

## Part 5 — Clean Up

- lab05: `terraform destroy` ลบไป 14 resources และ `state list` ว่าง
- bucket: ลบ 28 versions และ 20 delete markers แล้วรัน `aws s3 rb` สำเร็จ
- lab05-backend: `terraform destroy` ได้ 0 destroyed เพราะลบ bucket ไปก่อนแล้ว Terraform จึงเอา resource ออกจาก state ตอน refresh
- ไม่มี EC2 หรือ DynamoDB เหลืออยู่ และไม่พบ `access_key` / `secret_key` ในไฟล์ `.tf`
