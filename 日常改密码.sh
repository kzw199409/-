#!/bin/bash
rect=`date +%Y-%m`
recotime=`date +"%Y-%m-%d %H:%M"`
batchtime=`date +%Y-%m-%d`
testip=10.173.246
sunip=10.168.12
#transresetpasswd
reset()
{
iptest=`echo $2|awk -F . '{print $1 "." $2 "." $3}'`
if [ $iptest == $testip ]
then
timeout 30 ssh 10.168.28.29 "sh /home/kezw/chpasswd.sh $2 $3 $4"
elif [ $iptest == $sunip ]
then
SUNpasswd $2 $3 $4
else
timeout 30 ssh -o ConnectTimeout=5 -n $2 "pwdadm -f NOCHECK $3;echo $3:$4|chpasswd;pwdadm -c $3" 2>>/home/kezw/chpasswd/daliy/record/errout
fi
if [ $? -ne 0 ]
then
echo "$1 Reset failed."
fi
}

#expectsun
SUNpasswd()
{
ssh $1 "/export/home/kezw/chgpass.sh $2 $3"
}

main()
{
        echo ""
        echo "********************************************************************"
        echo "*                                                                  *"
        echo "*                      This is a password manager                  *"
        echo "*                       Please enter your choice                   *"
        echo "*                                                                  *"
        echo "********************************************************************"
        echo ""
        echo "1.Reset password."
        echo "2.Provide a single temporary password."
        echo "3.Provide a large number of partition temporary passwords.(If you select this option,Please select hosts file first,host file directory:/home/kezw/chpasswd/daliy/config/hosts)"
        echo "4.View temporary password modification record."
        echo "5.Query temporary password modification times."
        echo "6.View error log."
        echo "7.Exit."
        echo ""
read -p "Enter your choice: " opt 
case $opt in
1)
tranreset
;;
2)
tempasswd
;;
3)
largetempwd
;;
4)
templog
;;
5)
numtempasswd
;;
6)
errorlog
;;
7)
exit
;;
*)
echo "No such option,please enter agin!"
sleep 2
main
;;
esac
}

#reset passwd
tranreset()
{
echo "$recotime" >> /home/kezw/chpasswd/daliy/record/reset_record
while read line
do
{
reset $line
}&
done < /home/kezw/chpasswd/daliy/config/passwd_config
wait
echo "Reset complete!"
}

#temp passwd
tempasswd()
{
sdate=`date +%s`
read -p "Please enter the hostname or ip: " par
read -p "Please enter a temporary password: " pwd
read -p "Please enter a temporary password recovery time(format:HH:MM or HH:MM+3days): " time
iptest=`echo $par|awk -F . '{print $1 "." $2 "." $3}'`
if [[ $iptest == $testip ]]
then
timeout 30 ssh 10.168.28.29 "sh /home/kezw/chpasswd.sh $par root $pwd"
elif [ $iptest == $sunip ]
then
SUNpasswd $par root $pwd
else 
timeout 30 ssh -o ConnectTimeout=5 $par "pwdadm -f NOCHECK root;echo root:$pwd|chpasswd;pwdadm -c root" 2>/home/kezw/chpasswd/daliy/record/errout
fi
if [ $? -ne 0 ]
then
echo "Temporary password modification failed,You can see the error in the /home/kezw/chpasswd/daliy/record/errout"
return 1
fi
repwd=`grep $par /home/kezw/chpasswd/daliy/config/passwd_config|awk '{print $4}'`
if [[ $iptest == $testip ]]
then
(echo -n "timeout 30 ssh -n 10.168.28.29";echo -n ' "';echo -n "sh /home/kezw/chpasswd.sh $par root $repwd";echo '"') > /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate.sh
elif [ $iptest == $sunip ]
then
(echo -n "timeout 30 ssh -n $par";echo -n ' "';echo -n "/export/home/kezw/chgpass.sh root $repwd";echo '"') > /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate.sh
else
(echo -n "timeout 30 ssh $par";echo -n ' "';echo -n "pwdadm -f NOCHECK root;echo root:$repwd|chpasswd;pwdadm -c root";echo '"') > /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate.sh
fi
chmod 755 /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate.sh
at -f /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate.sh $time
while [ $? -ne 0 ]
do
read -p "wrong format,please enter again(format:HH:MM or HH:MM+3days): " time
at -f /home/kezw/chpasswd/daliy/config/tempasswd/tempasswd-$sdate $time
done
retime=`atq|grep $time|awk '{print $2 " " $3}'`
if [ -f /home/kezw/chpasswd/daliy/record/tempass-$rect ]
then
pt=`grep $batchtime /home/kezw/chpasswd/daliy/record/tempass-$rect|wc -l`
else
echo "--------------------------------------------------------------$batchtime----------------------------------------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
echo "$recotime Partition name: $par       temporary password: $pwd         recovery time: $retime"|tee -a /home/kezw/chpasswd/daliy/record/tempass-$rect
return 1
fi
if [[ $pt -eq 0 ]]
then
echo "--------------------------------------------------------------$batchtime----------------------------------------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
echo "$recotime Partition name: $par       temporary password: $pwd         recovery time: $retime"|tee -a /home/kezw/chpasswd/daliy/record/tempass-$rect
fi
}

#a large number of temp passwd
largetempwd()
{
sdate=`date +%s`
file=`ls /home/kezw/chpasswd/daliy/config/hosts`
echo "Here are the host files you can choose:"
read -p "$file `printf "\n  Please select host file: "`" sefi
while [ ! -f /home/kezw/chpasswd/daliy/config/hosts/$sefi ]
do
echo "file does not exist"
read -p "Please re-select: " sefi
done
read -p "Please enter a temporary password: " pwd
read -p "Please enter a temporary password recovery time(format:HH:MM or HH:MM+3days): " time
for i in `cat /home/kezw/chpasswd/daliy/config/hosts/$sefi`
do
{
repwd=`grep $i /home/kezw/chpasswd/daliy/config/passwd_config|awk '{print $4}'`
itest=`echo $i|awk -F . '{print $1 "." $2 "." $3}'`
if [[ $itest == $testip ]]
then
(echo -n "timeout 30 ssh -n 10.168.28.29";echo -n ' "';echo -n "sh /home/kezw/chpasswd.sh $i root $repwd";echo -n '"';echo "wait") >> /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd-$sdate.sh
elif [ $itest == $sunip ]
then
(echo -n "timeout 30 ssh -n $i";echo -n ' "';echo -n "/export/home/kezw/chgpass.sh root $repwd";echo -n '"';echo "wait") > /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd-$sdate.sh
else
(echo -n "timeout 30 ssh -o ConnectTimeout=5 -n $i";echo -n ' "';echo -n "pwdadm -f NOCHECK root;echo root:$repwd|chpasswd;pwdadm -c root";echo '"';echo "wait") >> /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd-$sdate.sh
fi
}
done
chmod 755 /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd.sh-$sdate.sh
at -f /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd-$sdate.sh $time
while [ $? -ne 0 ]
do
read -p "wrong format,please enter again(format:HH:MM or HH:MM+3days): " time
at -f /home/kezw/chpasswd/daliy/config/largpasswd/largpasswd-$sdate.sh $time
done
for n in `cat /home/kezw/chpasswd/daliy/config/hosts/$sefi`
do
{
ntest=`echo $n|awk -F . '{print $1 "." $2 "." $3}'`
if [[ $ntest == $testip ]]
then
(echo -n "timeout 30 ssh -n $n";echo -n ' "';echo -n "/export/home/kezw/chgpass.sh root $pwd";echo -n '"';echo "wait") > /home/kezw/chpasswd/daliy/config/largpasswd/sunlargpass-$sdate.sh
elif [ $ntest == $testip ]
then
(echo -n "timeout 30 ssh -n 10.168.28.29";echo -n ' "';echo -n "sh /home/kezw/chpasswd.sh $i root $pwd";echo -n '"';echo "wait") >> /home/kezw/chpasswd/daliy/config/largpasswd/testlargpass-$sdate.sh
else
(echo "pwdadm -f NOCHECK root;echo root:$pwd|chpasswd;pwdadm -c root") > /home/kezw/chpasswd/daliy/config/largpasswd/largtmpasswd-$sdate.sh
fi
}
done
pssh -h /home/kezw/chpasswd/daliy/config/hosts/$sefi -I < /home/kezw/chpasswd/daliy/config/largpasswd/largtmpasswd-$sdate.sh|tee -a /home/kezw/chpasswd/daliy/record/psshlargpass-$rect
if [ -f /home/kezw/chpasswd/daliy/config/largpasswd/sunlargpass-$sdate.sh ]
then
chmod 755 /home/kezw/chpasswd/daliy/config/largpasswd/sunlargpass-$sdate.sh
sh /home/kezw/chpasswd/daliy/config/largpasswd/sunlargpass-$sdate.sh 2>> /home/kezw/chpasswd/daliy/record/errout
fi
if [ -f /home/kezw/chpasswd/daliy/config/largpasswd/testlargpass-$sdate.sh ]
then
chmod 755 /home/kezw/chpasswd/daliy/config/largpasswd/testlargpass-$sdate.sh
sh /home/kezw/chpasswd/daliy/config/largpasswd/testlargpass-$sdate.sh 2>> /home/kezw/chpasswd/daliy/record/errout
fi
revtime=`atq|grep $time|awk '{print $2 " " $3}'`
retime=`atq|grep $time|awk '{print $2 " " $3}'`
if [ -f /home/kezw/chpasswd/daliy/record/tempass-$rect ]
then
pt=`grep $batchtime /home/kezw/chpasswd/daliy/record/tempass-$rect|wc -l`
else
echo "--------------------------------------------------------------$batchtime----------------------------------------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
pt=1
fi
if [ $pt -eq 0 ]
then
echo "--------------------------------------------------------------$batchtime----------------------------------------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
echo "--------------------------------------The following partition temporary password is provided in batch-----------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
else
echo "--------------------------------------The following partition temporary password is provided in batch-----------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
fi
for n in `cat /home/kezw/chpasswd/daliy/config/hosts/$sefi`
do
{
echo "$recotime Partition name: $i"|tee -a /home/kezw/chpasswd/daliy/record/tempass-$rect
}
done
echo "temporary password: $pwd"|tee -a /home/kezw/chpasswd/daliy/record/tempass-$rect
echo "recovery time: $revtime"|tee -a /home/kezw/chpasswd/daliy/record/tempass-$rect
echo "----------------------------------------------------------------------------------------------------------------------------------" >> /home/kezw/chpasswd/daliy/record/tempass-$rect
}

#view templog
templog()
{
clear
usedate=`ls /home/kezw/chpasswd/daliy/record|grep tempass|awk -F - '{print $2 "-" $3}'`
echo "You can view the logs for the following dates:"
echo $usedate
read -p "Please enter the month you want to view(format:YYYY-mm): " logdate
datecount=0
while [ $datecount -eq 0 ]
do
if [[ $logdate = [0-9][0-9][0-9][0-9]-[0-1][0-9] ]] && [[ `echo $logdate|awk -F - '{print $2}'` -le 12 ]] 2>> /dev/null
then
if [ -f /home/kezw/chpasswd/daliy/record/tempass-$logdate ]
then
more /home/kezw/chpasswd/daliy/record/tempass-$logdate
datecount=1
else
read -p "No logs for the month, please enter agin: " logdate
fi
else
read -p "The date format is incorrect, please re-enter(format:YYYY-mm): " logdate
fi
done
}

#number of tempasswd
numtempasswd()
{
numdate=`ls /home/kezw/chpasswd/daliy/record|grep tempass|awk -F - '{print $2 "-" $3}'`
echo "You can view the number of temporary password changes for the following dates:"
echo $numdate
read -p "Please enter the month you want to view(format:YYYY-mm): " numdate
numdatecount=0
while [ $numdatecount -eq 0 ]
do
if [[ $numdate = [0-9][0-9][0-9][0-9]-[0-1][0-9] ]] && [[ `echo $numdate|awk -F - '{print $2}'` -le 12 ]] 2>> /dev/null
then
if [ -f /home/kezw/chpasswd/daliy/record/tempass-$numdate ]
then
num=`grep -c Partition /home/kezw/chpasswd/daliy/record/tempass-$numdate`
echo "$numdate Temporary passwords are provided: $num"
numdatecount=1
else
read -p "No record for the month, please enter agin: " numdate
fi
else
read -p "The date format is incorrect, please re-enter(format:YYYY-mm): " numdate
fi
done
}

#view error log
errorlog()
{
more /home/kezw/chpasswd/daliy/record/errout
}
#########################
main
count=0
read -p "Press any key to continue,q to exit: " op
case $op in
q)
count=1
;;
*)
;;
esac
while [ $count -eq 0 ]
do
main
done