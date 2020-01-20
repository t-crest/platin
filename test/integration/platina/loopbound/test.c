void _exit (int e) {}
int main () { _exit(42); }

struct schedclass {
	struct schedclass *next;
};

struct schedclass idle = { .next = 0     };
struct schedclass cfs  = { .next = &idle };
struct schedclass rt   = { .next = &cfs  };
struct schedclass dl   = { .next = &rt   };
struct schedclass stop = { .next = &dl   };

int c_entry(int argc)
{
	int i = 0;
	struct schedclass *curr = &stop;
	while(curr) {
		#pragma platina lbound "5"
		curr = curr->next;
		i++;
	}
	return i;
}
