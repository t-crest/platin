---
format:          pml-0.1
triple:          armv7-none-none-eabi
bitcode-functions: 
  - name:            _exit
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:3'
        instructions:    
          - index:           '0'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            main
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:4'
        instructions:    
          - index:           '0'
            opcode:          call
            callees:         [ _exit ]
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            pick_next_task
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [ land.rhs, land.end ]
        src-hint:        'test.c:13'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          alloca
          - index:           '3'
            opcode:          alloca
          - index:           '4'
            opcode:          alloca
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          call
          - index:           '7'
            opcode:          store
            memmode:         store
          - index:           '8'
            opcode:          call
          - index:           '9'
            opcode:          call
          - index:           '10'
            opcode:          store
            memmode:         store
          - index:           '11'
            opcode:          call
          - index:           '12'
            opcode:          load
            memmode:         load
          - index:           '13'
            opcode:          getelementptr
          - index:           '14'
            opcode:          load
            memmode:         load
          - index:           '15'
            opcode:          load
            memmode:         load
          - index:           '16'
            opcode:          icmp
          - index:           '17'
            opcode:          br
      - name:            land.rhs
        predecessors:    [ entry ]
        successors:      [ land.end ]
        src-hint:        'test.c:22'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          getelementptr
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          getelementptr
          - index:           '5'
            opcode:          getelementptr
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          icmp
          - index:           '8'
            opcode:          br
      - name:            land.end
        predecessors:    [ land.rhs, entry ]
        successors:      [ if.then, if.end7 ]
        src-hint:        'test.c:22'
        instructions:    
          - index:           '0'
            opcode:          phi
          - index:           '1'
            opcode:          br
      - name:            if.then
        predecessors:    [ land.end ]
        successors:      [ if.then3, if.end ]
        src-hint:        'test.c:23'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          call
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          load
            memmode:         load
          - index:           '5'
            opcode:          call
            callees:         [ __any__ ]
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          load
            memmode:         load
          - index:           '8'
            opcode:          icmp
          - index:           '9'
            opcode:          br
      - name:            if.then3
        predecessors:    [ if.then ]
        successors:      [ again ]
        src-hint:        'test.c:29'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            if.end
        predecessors:    [ if.then ]
        successors:      [ if.then4, if.end6 ]
        src-hint:        'test.c:32'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          icmp
          - index:           '2'
            opcode:          xor
          - index:           '3'
            opcode:          br
      - name:            if.then4
        predecessors:    [ if.end ]
        successors:      [ if.end6 ]
        src-hint:        'test.c:32'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          load
            memmode:         load
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          load
            memmode:         load
          - index:           '4'
            opcode:          call
            callees:         [ __any__ ]
          - index:           '5'
            opcode:          store
            memmode:         store
          - index:           '6'
            opcode:          br
      - name:            if.end6
        predecessors:    [ if.then4, if.end ]
        successors:      [ return ]
        src-hint:        'test.c:37'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          br
      - name:            if.end7
        predecessors:    [ land.end ]
        successors:      [ again ]
        src-hint:        'test.c:22'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            again
        predecessors:    [ if.then14, if.end7, if.then3 ]
        successors:      [ for.cond ]
        loops:           [ again ]
        src-hint:        'test.c:41'
        instructions:    
          - index:           '0'
            opcode:          store
            memmode:         store
          - index:           '1'
            opcode:          br
      - name:            for.cond
        predecessors:    [ for.inc, again ]
        successors:      [ for.body, for.end ]
        loops:           [ for.cond, again ]
        src-hint:        'test.c:41'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          icmp
          - index:           '2'
            opcode:          br
      - name:            for.body
        predecessors:    [ for.cond ]
        successors:      [ if.then12, if.end16 ]
        loops:           [ for.cond, again ]
        src-hint:        'test.c:41'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          call
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          getelementptr
          - index:           '4'
            opcode:          bitcast
          - index:           '5'
            opcode:          load
            memmode:         load
          - index:           '6'
            opcode:          load
            memmode:         load
          - index:           '7'
            opcode:          load
            memmode:         load
          - index:           '8'
            opcode:          call
            callees:         [ __any__ ]
          - index:           '9'
            opcode:          store
            memmode:         store
          - index:           '10'
            opcode:          load
            memmode:         load
          - index:           '11'
            opcode:          icmp
          - index:           '12'
            opcode:          br
      - name:            if.then12
        predecessors:    [ for.body ]
        successors:      [ if.then14, if.end15 ]
        loops:           [ again ]
        src-hint:        'test.c:47'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          icmp
          - index:           '2'
            opcode:          br
      - name:            if.then14
        predecessors:    [ if.then12 ]
        successors:      [ again ]
        loops:           [ again ]
        src-hint:        'test.c:47'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          br
      - name:            if.end15
        predecessors:    [ if.then12 ]
        successors:      [ return ]
        src-hint:        'test.c:52'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          store
            memmode:         store
          - index:           '2'
            opcode:          br
      - name:            if.end16
        predecessors:    [ for.body ]
        successors:      [ for.inc ]
        loops:           [ for.cond, again ]
        src-hint:        'test.c:54'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            for.inc
        predecessors:    [ if.end16 ]
        successors:      [ for.cond ]
        loops:           [ for.cond, again ]
        src-hint:        'test.c:41'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          getelementptr
          - index:           '2'
            opcode:          load
            memmode:         load
          - index:           '3'
            opcode:          store
            memmode:         store
          - index:           '4'
            opcode:          br
      - name:            for.end
        predecessors:    [ for.cond ]
        successors:      [ for.cond17 ]
        src-hint:        'test.c:54'
        instructions:    
          - index:           '0'
            opcode:          call
          - index:           '1'
            opcode:          br
      - name:            for.cond17
        predecessors:    [ for.cond17, for.end ]
        successors:      [ for.cond17 ]
        loops:           [ for.cond17 ]
        src-hint:        'test.c:57'
        instructions:    
          - index:           '0'
            opcode:          br
      - name:            return
        predecessors:    [ if.end15, if.end6 ]
        successors:      [  ]
        src-hint:        'test.c:58'
        instructions:    
          - index:           '0'
            opcode:          load
            memmode:         load
          - index:           '1'
            opcode:          ret
    linkage:         ExternalLinkage
  - name:            c_entry
    level:           bitcode
    hash:            '0'
    blocks:          
      - name:            entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:62'
        instructions:    
          - index:           '0'
            opcode:          alloca
          - index:           '1'
            opcode:          alloca
          - index:           '2'
            opcode:          store
            memmode:         store
          - index:           '3'
            opcode:          call
          - index:           '4'
            opcode:          call
          - index:           '5'
            opcode:          call
            callees:         [ pick_next_task ]
          - index:           '6'
            opcode:          store
            memmode:         store
          - index:           '7'
            opcode:          load
            memmode:         load
          - index:           '8'
            opcode:          getelementptr
          - index:           '9'
            opcode:          load
            memmode:         load
          - index:           '10'
            opcode:          ret
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        pick_next_task
      block:           if.then
    origin:          platina.bc
    level:           bitcode
    type:            guard
    expression:      '(NUM_STOP_TASKS == 0) && (NUM_DL_TASKS == 0) && (NUM_RT_TASKS == 0)'
  - program-point:   
      function:        pick_next_task
      block:           for.cond
    origin:          platina.bc
    level:           bitcode
    type:            lbound
    expression:      NUM_SCHED_CLASSES
  - program-point:   
      function:        pick_next_task
      block:           if.then14
    origin:          platina.bc
    level:           bitcode
    type:            guard
    expression:      PICK_NEXT_TASK_CAN_FAIL
  - program-point:   
      function:        pick_next_task
      block:           for.end
    origin:          platina.bc
    level:           bitcode
    type:            guard
    expression:      PICK_NEXT_TASK_IS_BUGGY
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
relation-graphs: 
  - src:             
      function:        _exit
      level:           bitcode
    dst:             
      function:        '0'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
  - src:             
      function:        main
      level:           bitcode
    dst:             
      function:        '1'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
  - src:             
      function:        pick_next_task
      level:           bitcode
    dst:             
      function:        '2'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '2', '3' ]
        dst-successors:  [ '2', '3' ]
      - name:            '1'
        type:            exit
      - name:            '2'
        type:            progress
        src-block:       land.end
        dst-block:       '2'
        src-successors:  [ '4', '5' ]
        dst-successors:  [ '4', '5' ]
      - name:            '3'
        type:            progress
        src-block:       land.rhs
        dst-block:       '1'
        src-successors:  [ '2' ]
        dst-successors:  [ '2' ]
      - name:            '4'
        type:            progress
        src-block:       if.end7
        dst-block:       '8'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '5'
        type:            progress
        src-block:       if.then
        dst-block:       '3'
        src-successors:  [ '6', '7' ]
        dst-successors:  [ '6', '7' ]
      - name:            '6'
        type:            progress
        src-block:       if.end
        dst-block:       '5'
        src-successors:  [ '19', '20' ]
        dst-successors:  [ '19', '20' ]
      - name:            '7'
        type:            progress
        src-block:       if.then3
        dst-block:       '4'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '8'
        type:            progress
        src-block:       again
        dst-block:       '9'
        src-successors:  [ '9' ]
        dst-successors:  [ '9' ]
      - name:            '9'
        type:            progress
        src-block:       for.cond
        dst-block:       '10'
        src-successors:  [ '10', '11' ]
        dst-successors:  [ '10', '11' ]
      - name:            '10'
        type:            progress
        src-block:       for.body
        dst-block:       '11'
        src-successors:  [ '13', '14' ]
        dst-successors:  [ '13', '14' ]
      - name:            '11'
        type:            progress
        src-block:       for.end
        dst-block:       '17'
        src-successors:  [ '12' ]
        dst-successors:  [ '12' ]
      - name:            '12'
        type:            progress
        src-block:       for.cond17
        dst-block:       '18'
        src-successors:  [ '12' ]
        dst-successors:  [ '12' ]
      - name:            '13'
        type:            progress
        src-block:       if.end16
        dst-block:       '15'
        src-successors:  [ '18' ]
        dst-successors:  [ '18' ]
      - name:            '14'
        type:            progress
        src-block:       if.then12
        dst-block:       '12'
        src-successors:  [ '15', '16' ]
        dst-successors:  [ '15', '16' ]
      - name:            '15'
        type:            progress
        src-block:       if.end15
        dst-block:       '14'
        src-successors:  [ '17' ]
        dst-successors:  [ '17' ]
      - name:            '16'
        type:            progress
        src-block:       if.then14
        dst-block:       '13'
        src-successors:  [ '8' ]
        dst-successors:  [ '8' ]
      - name:            '17'
        type:            progress
        src-block:       return
        dst-block:       '19'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '18'
        type:            progress
        src-block:       for.inc
        dst-block:       '16'
        src-successors:  [ '9' ]
        dst-successors:  [ '9' ]
      - name:            '19'
        type:            progress
        src-block:       if.end6
        dst-block:       '7'
        src-successors:  [ '17' ]
        dst-successors:  [ '17' ]
      - name:            '20'
        type:            progress
        src-block:       if.then4
        dst-block:       '6'
        src-successors:  [ '19' ]
        dst-successors:  [ '19' ]
    status:          valid
  - src:             
      function:        c_entry
      level:           bitcode
    dst:             
      function:        '3'
      level:           machinecode
    nodes:           
      - name:            '0'
        type:            entry
        src-block:       entry
        dst-block:       '0'
        src-successors:  [ '1' ]
        dst-successors:  [ '1' ]
      - name:            '1'
        type:            exit
    status:          valid
...
---
format:          pml-0.1
triple:          armv7-none-none-eabi
machine-functions: 
  - name:            '0'
    level:           machinecode
    mapsto:          _exit
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:3'
        instructions:    
          - { index: '0', opcode: BX_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '1'
    level:           machinecode
    mapsto:          main
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:4'
        instructions:    
          - { index: '0', opcode: STMDB_UPD, size: 4, memmode: store }
          - { index: '1', opcode: BL_pred, callees: [ _exit ], size: 4, 
              branch-type: call }
          - { index: '2', opcode: MOVi, size: 4 }
          - { index: '3', opcode: LDMIA_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '2'
    level:           machinecode
    mapsto:          pick_next_task
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [ '1', '2' ]
        src-hint:        'test.c:15'
        instructions:    
          - { index: '0', opcode: STMDB_UPD, size: 4, memmode: store }
          - { index: '1', opcode: SUBri, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: MOVr, size: 4 }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: MOVi16, size: 4 }
          - { index: '7', opcode: MOVTi16, size: 4 }
          - { index: '8', opcode: STRi12, size: 4, memmode: store }
          - { index: '9', opcode: LDRi12, size: 4, memmode: load }
          - { index: '10', opcode: LDRi12, size: 4, memmode: load }
          - { index: '11', opcode: MOVi, size: 4 }
          - { index: '12', opcode: CMPrr, size: 4 }
          - { index: '13', opcode: STRi12, size: 4, memmode: store }
          - { index: '14', opcode: STRi12, size: 4, memmode: store }
          - { index: '15', opcode: STRi12, size: 4, memmode: store }
          - { index: '16', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '17', opcode: B, size: 4, branch-type: unconditional }
      - name:            '1'
        mapsto:          land.rhs
        predecessors:    [ '0' ]
        successors:      [ '2' ]
        src-hint:        'test.c:22'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: LDRi12, size: 4, memmode: load }
          - { index: '3', opcode: MOVi, size: 4 }
          - { index: '4', opcode: CMPrr, size: 4 }
          - { index: '5', opcode: MOVi16, size: 4 }
          - { index: '6', opcode: STRi12, size: 4, memmode: store }
          - { index: '7', opcode: B, size: 4, branch-type: unconditional }
      - name:            '2'
        mapsto:          land.end
        predecessors:    [ '0', '1' ]
        successors:      [ '3', '8' ]
        src-hint:        'test.c:22'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: TSTri, size: 4 }
          - { index: '2', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '3'
        mapsto:          if.then
        predecessors:    [ '2' ]
        successors:      [ '4', '5' ]
        src-hint:        'test.c:27'
        instructions:    
          - { index: '0', opcode: MOVi16, size: 4 }
          - { index: '1', opcode: MOVTi16, size: 4 }
          - { index: '2', opcode: LDRi12, size: 4, memmode: load }
          - { index: '3', opcode: LDRi12, size: 4, memmode: load }
          - { index: '4', opcode: LDRi12, size: 4, memmode: load }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: MOVr, size: 4 }
          - { index: '7', opcode: MOVr, size: 4 }
          - { index: '8', opcode: LDRi12, size: 4, memmode: load }
          - { index: '9', opcode: BLX, callees: [ __any__ ], size: 4, branch-type: call }
          - { index: '10', opcode: STRi12, size: 4, memmode: store }
          - { index: '11', opcode: CMPri, size: 4 }
          - { index: '12', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '13', opcode: B, size: 4, branch-type: unconditional }
      - name:            '4'
        mapsto:          if.then3
        predecessors:    [ '3' ]
        successors:      [ '9' ]
        src-hint:        'test.c:29'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '5'
        mapsto:          if.end
        predecessors:    [ '3' ]
        successors:      [ '6', '7' ]
        src-hint:        'test.c:32'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: CMPri, size: 4 }
          - { index: '2', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '6'
        mapsto:          if.then4
        predecessors:    [ '5' ]
        successors:      [ '7' ]
        src-hint:        'test.c:34'
        instructions:    
          - { index: '0', opcode: MOVi16, size: 4 }
          - { index: '1', opcode: MOVTi16, size: 4 }
          - { index: '2', opcode: LDRi12, size: 4, memmode: load }
          - { index: '3', opcode: LDRi12, size: 4, memmode: load }
          - { index: '4', opcode: LDRi12, size: 4, memmode: load }
          - { index: '5', opcode: STRi12, size: 4, memmode: store }
          - { index: '6', opcode: MOVr, size: 4 }
          - { index: '7', opcode: MOVr, size: 4 }
          - { index: '8', opcode: LDRi12, size: 4, memmode: load }
          - { index: '9', opcode: BLX, callees: [ __any__ ], size: 4, branch-type: call }
          - { index: '10', opcode: STRi12, size: 4, memmode: store }
          - { index: '11', opcode: B, size: 4, branch-type: unconditional }
      - name:            '7'
        mapsto:          if.end6
        predecessors:    [ '5', '6' ]
        successors:      [ '19' ]
        src-hint:        'test.c:37'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: STRi12, size: 4, memmode: store }
          - { index: '2', opcode: B, size: 4, branch-type: unconditional }
      - name:            '8'
        mapsto:          if.end7
        predecessors:    [ '2' ]
        successors:      [ '9' ]
        src-hint:        'test.c:22'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '9'
        mapsto:          again
        predecessors:    [ '8', '4', '13' ]
        successors:      [ '10' ]
        loops:           [ '9' ]
        src-hint:        'test.c:41'
        instructions:    
          - { index: '0', opcode: MOVi16, size: 4 }
          - { index: '1', opcode: MOVTi16, size: 4 }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '10'
        mapsto:          for.cond
        predecessors:    [ '9', '16' ]
        successors:      [ '11', '17' ]
        loops:           [ '10', '9' ]
        src-hint:        'test.c:41'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: CMPri, size: 4 }
          - { index: '2', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '11'
        mapsto:          for.body
        predecessors:    [ '10' ]
        successors:      [ '12', '15' ]
        loops:           [ '10', '9' ]
        src-hint:        'test.c:45'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: LDRi12, size: 4, memmode: load }
          - { index: '3', opcode: LDRi12, size: 4, memmode: load }
          - { index: '4', opcode: STRi12, size: 4, memmode: store }
          - { index: '5', opcode: MOVr, size: 4 }
          - { index: '6', opcode: MOVr, size: 4 }
          - { index: '7', opcode: LDRi12, size: 4, memmode: load }
          - { index: '8', opcode: BLX, callees: [ __any__ ], size: 4, branch-type: call }
          - { index: '9', opcode: STRi12, size: 4, memmode: store }
          - { index: '10', opcode: CMPri, size: 4 }
          - { index: '11', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '12', opcode: B, size: 4, branch-type: unconditional }
      - name:            '12'
        mapsto:          if.then12
        predecessors:    [ '11' ]
        successors:      [ '13', '14' ]
        loops:           [ '9' ]
        src-hint:        'test.c:47'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: CMPri, size: 4 }
          - { index: '2', opcode: Bcc, size: 4, branch-type: conditional }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '13'
        mapsto:          if.then14
        predecessors:    [ '12' ]
        successors:      [ '9' ]
        loops:           [ '9' ]
        src-hint:        'test.c:50'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '14'
        mapsto:          if.end15
        predecessors:    [ '12' ]
        successors:      [ '19' ]
        src-hint:        'test.c:52'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: STRi12, size: 4, memmode: store }
          - { index: '2', opcode: B, size: 4, branch-type: unconditional }
      - name:            '15'
        mapsto:          if.end16
        predecessors:    [ '11' ]
        successors:      [ '16' ]
        loops:           [ '10', '9' ]
        src-hint:        'test.c:54'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '16'
        mapsto:          for.inc
        predecessors:    [ '15' ]
        successors:      [ '10' ]
        loops:           [ '10', '9' ]
        src-hint:        'test.c:41'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: LDRi12, size: 4, memmode: load }
          - { index: '2', opcode: STRi12, size: 4, memmode: store }
          - { index: '3', opcode: B, size: 4, branch-type: unconditional }
      - name:            '17'
        mapsto:          for.end
        predecessors:    [ '10' ]
        successors:      [ '18' ]
        src-hint:        'test.c:57'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '18'
        mapsto:          for.cond17
        predecessors:    [ '17', '18' ]
        successors:      [ '18' ]
        loops:           [ '18' ]
        src-hint:        'test.c:57'
        instructions:    
          - { index: '0', opcode: B, size: 4, branch-type: unconditional }
      - name:            '19'
        mapsto:          return
        predecessors:    [ '7', '14' ]
        successors:      [  ]
        src-hint:        'test.c:58'
        instructions:    
          - { index: '0', opcode: LDRi12, size: 4, memmode: load }
          - { index: '1', opcode: ADDri, size: 4 }
          - { index: '2', opcode: LDMIA_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
  - name:            '3'
    level:           machinecode
    mapsto:          c_entry
    hash:            '0'
    blocks:          
      - name:            '0'
        mapsto:          entry
        predecessors:    [  ]
        successors:      [  ]
        src-hint:        'test.c:64'
        instructions:    
          - { index: '0', opcode: STMDB_UPD, size: 4, memmode: store }
          - { index: '1', opcode: SUBri, size: 4 }
          - { index: '2', opcode: MOVr, size: 4 }
          - { index: '3', opcode: STRi12, size: 4, memmode: store }
          - { index: '4', opcode: MOVi16, size: 4 }
          - { index: '5', opcode: MOVTi16, size: 4 }
          - { index: '6', opcode: MOVi, size: 4 }
          - { index: '7', opcode: STRi12, size: 4, memmode: store }
          - { index: '8', opcode: MOVr, size: 4 }
          - { index: '9', opcode: BL_pred, callees: [ pick_next_task ], 
              size: 4, branch-type: call }
          - { index: '10', opcode: STRi12, size: 4, memmode: store }
          - { index: '11', opcode: LDRi12, size: 4, memmode: load }
          - { index: '12', opcode: ADDri, size: 4 }
          - { index: '13', opcode: LDMIA_RET, size: 4, branch-type: return }
    linkage:         ExternalLinkage
modelfacts:      
  - program-point:   
      function:        '2'
      block:           '3'
      instruction:     '9'
    origin:          platina
    level:           machinecode
    type:            callee
    expression:      '[sched.c:endless]'
  - program-point:   
      function:        '2'
      block:           '6'
      instruction:     '9'
    origin:          platina
    level:           machinecode
    type:            callee
    expression:      '[sched.c:endless]'
  - program-point:   
      function:        '2'
      block:           '11'
      instruction:     '8'
    origin:          platina
    level:           machinecode
    type:            callee
    expression:      '[sched.c:dl_ok, sched.c:rt_ok, sched.c:stop_ok]'
...
