# fish completion for kome
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Commands come from `kome --commands` and presets from `kome list`.

function __kome_presets
    kome list 2>/dev/null | string split -f1 \t
end

complete -c kome -f
complete -c kome -n __fish_use_subcommand -a '(kome --commands 2>/dev/null)'
complete -c kome -n __fish_use_subcommand -l help -d 'show help'
complete -c kome -n __fish_use_subcommand -l version -d 'show the version'

complete -c kome -n '__fish_seen_subcommand_from apply deps doctor' -a '(__kome_presets)'
complete -c kome -n '__fish_seen_subcommand_from apply' -s n -l dry-run -d 'show the plan, change nothing'
complete -c kome -n '__fish_seen_subcommand_from apply' -s v -l verbose -d 'say what each unit does'
complete -c kome -n '__fish_seen_subcommand_from apply' -l partial -d 'apply even if something is missing'
complete -c kome -n '__fish_seen_subcommand_from doctor' -l info -d 'print facts about this system'
complete -c kome -n '__fish_seen_subcommand_from doctor' -l fix -d 'fix what doctor found'
complete -c kome -n '__fish_seen_subcommand_from restore' -a 'original previous'
complete -c kome -n '__fish_seen_subcommand_from status' -s v -l verbose -d 'show what changed'
complete -c kome -n '__fish_seen_subcommand_from purge' -s y -l yes -d 'do not ask for confirmation'
complete -c kome -n '__fish_seen_subcommand_from apply' -l palette -r -a '(kome list palettes 2>/dev/null | string split -f1 \t)' -d 'use this palette'
complete -c kome -n '__fish_seen_subcommand_from apply' -l style -r -a '(kome list styles 2>/dev/null | string split -f1 \t)' -d 'use this style'
complete -c kome -n '__fish_seen_subcommand_from list' -a 'presets palettes styles'
complete -c kome -n '__fish_seen_subcommand_from validate preview' -a '(__kome_presets)'
complete -c kome -n '__fish_seen_subcommand_from preview' -s o -r -F -d 'save the screenshots here'
complete -c kome -n '__fish_seen_subcommand_from preview' -s d -x -d 'seconds to wait after each apply'
