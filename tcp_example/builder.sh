clear
echo "ARM Assembly Builder"
as main.s -o main.o
ld -w main.o -o tcpserver
