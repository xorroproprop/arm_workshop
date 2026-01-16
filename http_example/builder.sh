clear
echo "ARM Assembler HTTP Server"

as main.s -o main.o
ld main.o -o http_server