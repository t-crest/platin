#include "test.h"

// Stub for CFS, Idle
static struct task_struct *endless(struct rq *rq, struct task_struct *prev) {
	struct task_struct *i = prev;
	while(i->next != 0) {
		i = i->next;
	}
	return i;
}

// functions
static struct task_struct *rt_ok  (struct rq *rq, struct task_struct *prev) { return prev; }
static struct task_struct *dl_ok  (struct rq *rq, struct task_struct *prev) { return prev; }
static struct task_struct *stop_ok(struct rq *rq, struct task_struct *prev) { return prev; }

// Scheduling classes
const struct sched_class idle_sched_class = { .next = 0                 , .pick_next_task = endless };
const struct sched_class fair_sched_class = { .next = &idle_sched_class , .pick_next_task = endless };
const struct sched_class rt_sched_class   = { .next = &fair_sched_class , .pick_next_task = rt_ok   };
const struct sched_class dl_sched_class   = { .next = &rt_sched_class   , .pick_next_task = dl_ok   };
const struct sched_class stop_sched_class = { .next = &dl_sched_class   , .pick_next_task = stop_ok };
