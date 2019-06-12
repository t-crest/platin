flowfacts:
- classification: system-global
  level: gcfg
  lhs:
  - factor: 1
    program-point: {frequency-variable: flow_var_isr_entry_0}
  op: minimal-interarrival-time
  origin: user
  rhs: 20000
  scope: {gcfg: timing-0}
- classification: system-global
  level: machinecode
  lhs: []
  op: less-equal
  origin: user
  rhs: -1
  scope: {function: __OS_ASTSchedule}
format: pml-0.1
global-cfgs:
- blocks:
  - {function: irq_entry, index: 0, name: isr_entry_block}
  - {entry-block: BB11, exit-block: BB14, function: OSEKOS_TASK_FUNC_Control, index: 1,
    name: ABB10, subtask: <Subtask Control>}
  - {entry-block: BB111, exit-block: BB20, function: OSEKOS_ISR_ISR1, index: 2, name: ABB4,
    subtask: <Subtask ISR1 ISR>}
  devices:
  - {energy_stay_off: 0, energy_stay_on: 80, energy_turn_off: 0, energy_turn_on: 0,
    index: 0, name: Peripheral}
  entry-nodes: [0]
  exit-nodes: [0]
  level: bitcode
  name: timing-0
  nodes:
  - abb: 1
    abb-name: ABB10
    devices: [0]
    global-successors: [1]
    index: 0
    local-successors: []
    loops: [0]
  - abb: 0
    abb-name: ABB142/kickoff
    devices: [0]
    frequency-variable: flow_var_isr_entry_0
    global-successors: []
    index: 1
    isr_entry: true
    local-successors: [2]
    loops: [0]
  - abb: 2
    abb-name: ABB4
    devices: [0]
    global-successors: []
    index: 2
    local-successors: [3]
    loops: [0]
    microstructure: true
  - abb-name: ABB140/iret
    cost: 0
    devices: [0]
    global-successors: [0]
    index: 3
    local-successors: []
    loops: [0]
    microstructure: true
triple: thumbv7m--
