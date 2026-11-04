### Checkpoint 1

```text
> 5 + 3 * 2
11
> 10 % 3
1
> "a" == "a" && 1 < 2
true
> 3 > 5 ? "big" : "small"
"small"
> var.environment == "prod" ? "t3.large" : "t3.micro"
"t3.micro"
> upper("terraform")
"TERRAFORM"
> join("-", ["ipa", "lab03", "web"])
"ipa-lab03-web"
> split(",", "a,b,c")
tolist([
  "a",
  "b",
  "c",
])
> format("%s-%03d", "web", 7)
"web-007"
> substr("hello world", 0, 5)
"hello"
> trimspace(" padded ")
"padded"
> replace("my_project_name", "_", "-")
"my-project-name"
> length(["a", "b", "c"])
3
> merge({a = 1}, {b = 2})
{
  "a" = 1
  "b" = 2
}
> keys({name = "kmitl", age = 60})
[
  "age",
  "name",
]
> values({name = "kmitl", age = 60})
[
  60,
  "kmitl",
]
> lookup({a = 1, b = 2}, "c", "default")
"default"
> contains(["dev", "prod"], "dev")
true
> toset(["a", "b", "a"])
toset([
  "a",
  "b",
])
> flatten([[1, 2], [3, 4]])
[
  1,
  2,
  3,
  4,
]
> zipmap(["a", "b"], [1, 2])
{
  "a" = 1
  "b" = 2
}
> regex("[0-9]+", "instance-42-web")
"42"
> regexall("[a-z]+", "ab12cd34ef")
tolist([
  "ab",
  "cd",
  "ef",
])
> can(regex("^t[23]\\.", "t3.micro"))
true
> can(regex("^t[23]\\.", "m5.large"))
false
> tostring(42)
"42"
> tonumber("3.14")
3.14
> tolist(toset(["b", "a"]))
tolist([
  "a",
  "b",
])
> try(tonumber("not-a-number"), 0)
0
> can(tonumber("not-a-number"))
false
```

---

### Question 1: What is the difference between try() and can()? When would you reach for each?

**<u>Answer:</u>** 
`try()` เอาไว้ใช้เพื่อเวลารันโค้ดถ้าโค้ดทำงานได้ก็จะตอบกลับมาเป็น Output ของโค้ดนั้นแต่ถ้ามี Error ก็จะตอบกลับมาเป็นรูปแบบที่กำหนดเอาไว้ เอาไว้ใช้ป้องกัน Error เวลารันโค้ด ส่วน `can()` เอาไว้เช็คว่าโค้ดรันผ่านไหม โดยค่าที่ตอบกลับมาจะเป็น true หรือ false เพื่อตรวจสอบความถูกต้อง

---

### Checkpoint 2

| Expression | dev (default) | `-var="environment=prod"` |
|---|---|---|
| `local.effective_instance_type` | `"t3.micro"` | `"t3.medium"` |
| `local.is_production` | `false` | `true` |

---

### Question 2: Which instance does Terraform destroy? Now imagine you had 3 instances and wanted to remove the middle one. What would count do? This is the classic count pitfall.

**<u>Answer:</u>** 
พอลด `instance_count` เป็น 1 Terraform จะลบตัวท้ายสุดคือ `aws_instance.web[1]` เพราะ count ใช้แค่ตัวเลข index เรียงจาก 0 จะลบจากท้ายก่อนเสมอ

ถ้ามี 3 ตัวแล้วอยากเอาตัวกลาง (`web[1]`) ออกใช้ count ทำไม่ได้ ถ้าใช้ก็จะไปลบ `web[2]` อยู่ดี (`web[1]`) ก็ยังอยู่ แต่ว่าถ้า resource สร้างมาจาก list แล้วเราลบตัวกลางออกจาก list ตัวท้ายจะเลื่อน index ขึ้นมา Terraform ก็จะเห็นว่า `web[1]` มี config เปลี่ยนไปต้อง update แล้วค่อยไปลบ `web[2]` ทิ้ง ที่ว่ามาคือ count pitfall

---

### Checkpoint 3

**<u>Answer:</u>** 
ตอนใช้ count address จะเป็นเลข index พอเปลี่ยนเป็น for_each address กลายเป็น key ที่เราตั้งเอง:

```text
module.web_server.aws_instance.server["api"]
module.web_server.aws_instance.server["web"]
```

แล้วลองเอา `api` ออกจาก map ผล plan :

```text
  # module.web_server.aws_instance.server["api"] will be destroyed
  # (because key ["api"] is not in for_each map)
Plan: 0 to add, 0 to change, 1 to destroy.
```

หลัง apply ลอง curl ทั้งสองเครื่องได้

---

### Question 3: Removing api from the for_each map destroys only the api instance. Explain in one sentence why for_each is safer than count for non-identical resources.

**<u>Answer:</u>** 
เพราะ for_each จำ resource แต่ละตัวด้วย key ไม่ได้จำด้วยลำดับเหมือนตอนใช้ list พอลบ key ไหน Terraform ก็ลบแค่ตัวนั้น ตัวอื่นไม่ต้องมาอัปเดต

---

### Question 4: Rewrite [for k, v in var.servers : k if v.role == "backend"] using only functions (keys, lookup, etc.). Which version is more readable?

**<u>Answer:</u>** 
ลองใช้ `matchkeys` ได้:

```
matchkeys(keys(var.servers), values(var.servers)[*].role, ["backend"])
```

แต่ว่าแบบ `for ... if` อ่านง่ายกว่า สามารถดูได้ "เอา key ที่ role เป็น backend" ส่วน matchkeys ต้องมานั่งดูว่า argument 

---

### Checkpoint 4

**<u>Answer:</u>** 

```text
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Application port added by the caller"
              + from_port        = 8080
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 8080
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTP"
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = [
                  + "10.0.0.0/8",
                ]
              + description      = "SSH from the office network"
              + from_port        = 22
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 22
            },
        ]
```

---

### Checkpoint 5

**<u>Answer:</u>** 

| | `terraform plan` (dev) | `terraform plan -var="environment=prod"` |
|---|---|---|
| ingress ports | 80, 8080, 22 | 80, 8080 |
| instance_type | t3.micro | t3.medium |
| root volume_size | 8 GB | 30 GB |
| root volume encrypted | true | true |

---

### Question 5: In the dynamic "ingress" block, what do ingress.key and ingress.value refer to? What would they be if for_each were a map instead of a list?

**<u>Answer:</u>** 
ชื่อ iterator ใน `dynamic` block จะตรงกับชื่อ label ของ block เสมอ (เช่น `ingress`) โดยหาก `for_each` เป็น **list** ตัว `ingress.key` จะเป็น index (0, 1, 2) และ `ingress.value` จะเป็นข้อมูลทั้ง object ทำให้เรียกใช้ attribute ย่อยได้ทันที เช่น `ingress.value.port` แต่หาก `for_each` เป็น **map** ตัว `ingress.key` จะเปลี่ยนเป็น key ของ map (string) และ `ingress.value` จะเป็น value ที่คู่กับ key นั้นแทน