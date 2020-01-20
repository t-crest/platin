#include "test.h"

void _exit (int e) {}
int main () { _exit(42); }

extern const struct sched_class idle_sched_class;
extern const struct sched_class fair_sched_class;
extern const struct sched_class rt_sched_class;
extern const struct sched_class dl_sched_class;
extern const struct sched_class stop_sched_class;

struct task_struct *
pick_next_task(struct rq *rq, struct task_struct *prev)
{
	const struct sched_class *class = &fair_sched_class;
	struct task_struct *p;

	/*
	 * Optimization: we know that if all tasks are in
	 * the fair class we can call that function directly:
	 */
	if (likely(prev->sched_class == class &&
		   rq->nr_running == rq->cfs.h_nr_running)) {
		#pragma platina guard "False"

		#pragma platina callee "[sched.c:endless]"
		p = fair_sched_class.pick_next_task(rq, prev);
		if (unlikely(p == RETRY_TASK))
			goto again;

		/* assumes fair_sched_class->next == idle_sched_class */
		if (unlikely(!p)) {
			#pragma platina callee "[sched.c:endless]"
			p = idle_sched_class.pick_next_task(rq, prev);
		}

		return p;
	}

again:
	for_each_class(class) {
		// We could do a refinement here
		#pragma platina lbound "5"
		#pragma platina callee "[sched.c:dl_ok, sched.c:rt_ok, sched.c:stop_ok]"
		p = class->pick_next_task(rq, prev);
		if (p) {
			if (unlikely(p == RETRY_TASK)) {
				// THIS is cheating :/
				#pragma platina guard "False"
				goto again;
			}
			return p;
		}
	}

	#pragma platina guard "False"
	BUG(); /* the idle class will always have a runnable task */
}

static struct rq mainrq;

int c_entry(int argc)
{
	struct task_struct *next = pick_next_task(&mainrq, 0);
	return next->id;
}
