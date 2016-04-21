format: pml-0.1
triple: patmos-unknown-unknown-elf
global-cfgs:
  - name: system
    level: bitcode
    blocks:
      - name: ABB0
        function: Handler11
        index: 0
        entry-block: BB9
        exit-block: BB13
      - name: ActivateTask
        function: Handler11
        index: 1
        entry-block: BB0
        exit-block: BB0
      - name: ABB2
        function: Handler11
        index: 2
        entry-block: BB1
        exit-block: BB17
      - name: ABB3
        function: Handler11
        index: 3
        entry-block: BB2
        exit-block: BB2
    edges:
      - index: 0
        abb: 1
        successor-edges: [1]
      - index: 1
        abb: 1
        successor-edges: []
      #- index: 1
      #  abb: 0
      #  successor-edges: [ ]
      #- index: 2
      #  abb: 1
      #  successor-edges: [ ]
