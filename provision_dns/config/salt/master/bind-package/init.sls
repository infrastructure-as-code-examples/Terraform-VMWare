bind:
  pkg:
    - installed

bind-utils:
  pkg:
    - installed

named:
  service.running:
    - enable: True
    - watch:
      - pkg: bind
