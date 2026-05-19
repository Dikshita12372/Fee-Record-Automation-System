

STUDENT_FILE="students.csv"
PAYMENT_FILE="payments.csv"
FINE_FILE="fines.csv"

# Create CSV files with headers if not exists
[ ! -f $STUDENT_FILE ] && echo "StudentID,RollNo,Name,CourseYear,AdmissionYear,City,AcademicFee,MiscFee,PaidAmount,TotalPayable" > $STUDENT_FILE
[ ! -f $PAYMENT_FILE ] && echo "StudentID,TransactionID,Date,Amount,Mode,RemainingFee" > $PAYMENT_FILE
[ ! -f "$FINE_FILE" ] && echo "StudentID,Date,Type,Amount,Reason" > "$FINE_FILE"



while true
do
echo "===================================="
echo "   FEE RECORD AUTOMATION SYSTEM"
echo "===================================="
echo "1. Add Student Record"
echo "2. View Total Students"
echo "3. View Student Record"
echo "4. Delete Student Record"
echo "5. Add Miscellaneous Fee / Late Fee"
echo "6. Pay Fee (Installment Allowed)"
echo "7. View Fee Status"
echo "8. Generate Receipt"
echo "9. Exit"
echo "===================================="
echo -n "Enter choice: " ; read ch

case $ch in

1)
echo -n "Student ID: " ; read sid
echo -n "Roll Number: " ; read roll
echo -n "Name: "; read name
echo -n "Course & Year: " ; read course
echo -n "Admission Year: " ; read ayear
echo -n "City: " ; read city
echo -n "Academic Fee: " ; read afee

misc=0
paid=0
total=$afee

echo "$sid,$roll,$name,$course,$ayear,$city,$afee,$misc,$paid,$total" >> $STUDENT_FILE
echo "Student Record Added Successfully"
;;

2)
# Count total students (excluding header)
total_students=$(($(wc -l < "$STUDENT_FILE") - 1))
echo "--------------------------------"
echo "Total Students in Database: $total_students"
echo "--------------------------------"

# Print table header
printf "%-10s | %-10s | %-20s | %-15s | %-12s | %-10s | %-10s | %-10s | %-10s | %-10s\n" \
"StudentID" "RollNo" "Name" "CourseYear" "Admission" "City" "AcadFee" "MiscFee" "PaidAmt" "Total"
echo "============================================================================================================================="

# Read students and print each line
tail -n +2 "$STUDENT_FILE" | while IFS=',' read -r sid roll name course ayear city afee misc paid total; do
    printf "%-10s | %-10s | %-20s | %-15s | %-12s | %-10s | %-10s | %-10s | %-10s | %-10s\n" \
    "$sid" "$roll" "$name" "$course" "$ayear" "$city" "$afee" "$misc" "$paid" "$total"
done

echo "============================================================================================================================="
;;

3)
echo -n "Enter Student ID: " ; read sid

record=$(grep "^$sid," "$STUDENT_FILE")

if [ -z "$record" ]; then
  echo "Student record not found"
else
  IFS="," read id roll name course ayear city afee misc paid total <<< "$record"

  echo "--------------------------------"
  echo "        STUDENT DETAILS"
  echo "--------------------------------"
  echo "Student ID        : $id"
  echo "Roll Number       : $roll"
  echo "Name              : $name"
  echo "Course & Year     : $course"
  echo "Admission Year    : $ayear"
  echo "City              : $city"
  echo "Academic Fee      : Rs.$afee"
  echo "Miscellaneous Fee : Rs.$misc"
  echo "Paid Amount       : Rs.$paid"
  echo "Total Payable     : Rs.$total"
  echo "--------------------------------"
fi
;;

4)
echo -n "Enter Student ID to delete: " ; read sid
grep -v "^$sid," $STUDENT_FILE > temp.csv
mv temp.csv $STUDENT_FILE
echo "Record Deleted"
;;

5)
echo -n "Enter Student ID: " ; read sid

record=$(grep "^$sid," "$STUDENT_FILE")
if [ -z "$record" ]; then
  echo "Student not found"
  continue
fi

IFS="," read id roll name course ayear city afee misc paid total <<< "$record"

echo "--------------------------------"
echo "          FINE DETAILS"
echo "--------------------------------"
echo "Student Name : $name"
echo "Total Fine   : Rs. $misc"
echo "--------------------------------"

echo "Previous Fines:"
echo "Date | Type | Amount | Reason | Status"
echo "--------------------------------"

if grep -q "^$sid," "$FINE_FILE"; then
  grep "^$sid," "$FINE_FILE" | while IFS=',' read fsid fdate ftype famt freason
  do
      # Remove time from date
      fdate_only=$(echo $fdate | cut -d' ' -f1)
      # Determine status: paid if paid amount covers the fine, else pending
      if [ $paid -ge $famt ]; then
          fstatus="Paid"
      else
          fstatus="Pending"
      fi
      echo "$fdate_only | $ftype | Rs.$famt | $freason | $fstatus"
  done
else
  echo "No fines added yet"
fi

echo "--------------------------------"

echo -n "Add New Fine? (y/n): " ; read ch
[ "$ch" != "y" ] && continue

echo -n "Fine Type (ID Card / Library / Property / Late Fee): " ; read type
echo -n "Amount: " ; read amt
echo -n "Reason: " ; read reason

misc=$((misc + amt)) 
total=$((afee + misc)) 



# Update student record
sed "s|^$sid,.*|$sid,$roll,$name,$course,$ayear,$city,$afee,$misc,$paid,$total|" "$STUDENT_FILE" > temp.csv 
mv temp.csv "$STUDENT_FILE"


# Save fine with date (without time if you want, or keep timestamp for record)
fdate=$(date +"%d-%m-%Y") 
echo "$sid,$fdate,$type,$amt,$reason" >> "$FINE_FILE"

echo "--------------------------------"
echo "Fine Added Successfully!"
echo "Updated Total Fine   : Rs. $misc"
echo "Updated Total Payable: Rs. $total"
echo "--------------------------------"
;;

6)
echo -n "Enter Student ID: " ; read sid

record=$(grep "^$sid," "$STUDENT_FILE")
if [ -z "$record" ]; then
  echo "Student not found"
  continue
fi

IFS="," read id roll name course ayear city afee misc paid total <<< "$record"
remain=$((total - paid))
combined=$((afee + misc))

echo "--------------------------------"
echo "        FEE BREAKDOWN"
echo "--------------------------------"
echo "Student Name        : $name"
echo "Academic Fee        : Rs.$afee"
echo "Fine / Misc Fee     : Rs.$misc"
echo "--------------------------------"
echo "Total Payable       : Rs.$combined"
echo "Paid Amount         : Rs.$paid"
echo "Remaining Fee       : Rs.$remain"
echo "--------------------------------"

echo "Previous Installments:"
echo "Date | Amount | Mode"
echo "--------------------------------"
grep "^$sid," "$PAYMENT_FILE" | awk -F',' '{ print $3 " | Rs." $4 " | " $5 }'
echo "--------------------------------"

if [ $remain -eq 0 ]; then
  echo "Fee already fully paid"
  continue
fi

# Remove minimum payment check
echo -n "Enter Amount to Pay: " ; read pay
echo -n "Mode (Cash/UPI/Card): " ; read mode

if [ $pay -gt $remain ]; then
  echo "Cannot pay more than remaining fee"
  continue
fi

paid=$((paid + pay))
remain=$((total - paid))

#update record
sed "s|^$sid,.*|$sid,$roll,$name,$course,$ayear,$city,$afee,$misc,$paid,$total|" "$STUDENT_FILE" > temp.csv
mv temp.csv "$STUDENT_FILE"

txn="TXN$(date +%s)"
pdate=$(date +"%d-%m-%Y %H:%M")

#payment
echo "$sid,$txn,$pdate,$pay,$mode,$remain" >> "$PAYMENT_FILE"

echo "--------------------------------"
echo "Payment Successful!"
echo "New Paid Amount   : Rs.$paid"
echo "Remaining Fee     : Rs.$remain"
echo "--------------------------------"
;;

7)
echo -n "Enter Student ID: " ; read sid

# Check if student exists
old=$(grep "^$sid," "$STUDENT_FILE")
if [ -z "$old" ]; then
  echo "Student not found"
  continue
fi

IFS="," read id roll name course ayear city afee misc paid total <<< "$old"
remain=$((total - paid))
status="Pending"
[ $remain -eq 0 ] && status="Completed"

echo "--------------------------------"
echo "        FEE STATUS"
echo "--------------------------------"
echo "Student Name       : $name"
echo "Academic Fee       : Rs.$afee"
echo "Miscellaneous Fee  : Rs.$misc"
echo "Total Payable      : Rs.$total"
echo "Paid Amount        : Rs.$paid"
echo "Remaining Fee      : Rs.$remain"
echo "Status             : $status"
echo "--------------------------------"
;;

8)
echo -n "Enter Student ID: " ; read sid

# Check if student exists
record=$(grep "^$sid," "$STUDENT_FILE")
if [ -z "$record" ]; then
  echo "Student not found"
  continue
fi

IFS="," read id roll name course ayear city afee misc paid total <<< "$record"
remain=$((total - paid))

# Get last payment, if any
last_payment=$(grep "^$sid," "$PAYMENT_FILE" | tail -1)

college="Vivekanand Education Society's College of Arts, Science and Commerce"

echo "===================================================="
echo "                $college"
echo "===================================================="
echo "                 FEE RECEIPT"
echo "----------------------------------------------------"
echo "Student Details:"
echo "Student ID        : $id"
echo "Roll Number       : $roll"
echo "Name              : $name"
echo "Course & Year     : $course"
echo "Admission Year    : $ayear"
echo "City              : $city"
echo "----------------------------------------------------"
echo "Fee Details:"
echo "Academic Fee      : Rs.$afee"
echo "Miscellaneous Fee : Rs.$misc"
echo "Total Payable     : Rs.$total"
echo "Paid Amount       : Rs.$paid"
echo "Remaining Fee     : Rs.$remain"
echo "----------------------------------------------------"

if [ -z "$last_payment" ]; then
    echo "No payments made yet"
else
    IFS="," read psid txn pdate amt mode remainamt <<< "$last_payment"
    pdate=$(date +"%d-%m-%Y") 
    echo "Last Payment Details:"
    echo "Transaction ID    : $txn"
    echo "Date of Payment   : $pdate"
    echo "Amount Paid       : Rs.$amt"
    echo "Payment Mode      : $mode"
    echo "Remaining Fee     : Rs.$remainamt"
fi

echo "----------------------------------------------------"
echo "              THANK YOU FOR YOUR PAYMENT"
echo "===================================================="
;;

9)
echo "Thank You!"
exit
;;

*)
echo "Invalid Choice"
;;

esac
done