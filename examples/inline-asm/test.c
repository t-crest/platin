int main() {
	asm volatile(
            "li   $r5 = 0xffaa5511;"
            "mfs  $r1 = $s6;"
            "add  $r1 = $r1, $r5;"
            );
}
