#pragma once

#define RETRY_TASK 0
#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)
#define BUG() for(;;);

struct rq;
struct task_struct;


#define sched_class_highest (&stop_sched_class)
#define for_each_class(class) \
   for (class = sched_class_highest; class; class = class->next)

struct sched_class {
	const struct sched_class *next;

	struct task_struct * (*pick_next_task) (struct rq *rq,
						struct task_struct *prev);
};

struct task_struct {
	int id;
	struct sched_class *sched_class;
	struct task_struct *next;
};

struct cfs_dummy {
	unsigned int h_nr_running;
};

struct rq {
	unsigned int nr_running;
	struct cfs_dummy cfs;
};

