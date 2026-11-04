### Question 1: After you apply, what does Terraform print where a sensitive value would appear? Is the value still stored in the state file? (Answer from the book, Chapter 3.3.)
**ตอบ** Terraform จะซ่อนค่าเอาไว้และ print "sensitive value" ออกมาแต่ค่ายังคงถูกเก็บเป็น Plain text อยู่ใน file terraform.tfstate อยู่ดี

---

### Question 2: What is the difference between a local and a variable with a default? Give one situation where only a local will work.
**ตอบ** Local จะเป็นค่าที่ใช้ได้เฉพาะใน Module เท่านั้นแต่ถ้าใช้เป็น Variable สามารถเข้าถึงจาก Module ภายนอกได้ด้วยถ้าต้องการเก็บค่าอะไรที่ต้องเปลี่ยนค่าต้องใช้เป็น Local เท่านั้นเนื่องจาก Variable สามารถเก็บได้เฉพาะค่าคงที่เท่านั้น

---

### Question 3: Terraform will likely plan to destroy and recreate your resources even though the configuration is functionally identical. Why?
**ตอบ** บาง Resource ใน AWS ไม่สามารถที่จะแก้ไขได้เลยทำให้เมื่่อต้องการที่จะแก้ไข Resource นั้น Terraform จึงต้องทำการ Destroy และ Recreate ใหม่

---

### Question 4: Why is version = "~> 5.0" required for a registry module but not for a local ./modules/... module?
**ตอบ** Registry Module เป็น Module ที่มีการดึงมาจากภายนอกด้วยทำให้มีการอัปเดต Version อยู่เรื่อยๆ ทำให้ต้องมีการกำหนด Version ขั้นต่ำเอาไว้เพื่อให้ใช้คำสั่งได้อย่างถูกต้องแต่ Local Module file ทั้งหมดอยู่ใน Directory เดียวกันทำให้เมื่อมีการอัปเดตจะมีการเปลี่ยนแปลงทันทีทำให้ไม่ต้องมีการกำหนด Version เอาไว้