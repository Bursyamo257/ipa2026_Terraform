# Pitfall B: tag ที่เปลี่ยนทุกครั้ง

อาการ: เมื่อใส่ `LastPlanned = timestamp()` ใน `local.common_tags` แผนจะแสดง tag เปลี่ยนทุกครั้ง เพราะ `timestamp()` ให้ค่าใหม่ทุกครั้งที่ประเมิน ทำให้ค่าที่บันทึกใน state ไม่ตรงกับค่าจาก config

วิธีแก้ที่เลือกใช้: ลบบรรทัด `LastPlanned` ออก ไม่ควรใส่ค่าที่เปลี่ยนเองตลอดเวลาใน config หากต้องการเวลา deploy ให้เก็บค่าแบบคงที่ใน state เช่น resource `time_static` ตามโจทย์ Lab ถัดไป

อีกวิธีคือ `lifecycle { ignore_changes = [tags["LastPlanned"]] }` แต่เป็นการซ่อน diff และต้องใส่ในแต่ละ resource จึงไม่เลือกใช้
