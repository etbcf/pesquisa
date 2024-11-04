#!/usr/bin/env bash

# Função para autocompletar nomes de funções, aliases e git aliases
_autocomplete_names() {
	# Capture Bash aliases correctly
	local aliases=()
	mapfile -t aliases < <(alias | awk -F'=' '{print $1}' | sed 's/alias //')

	# Capture Bash functions
	local functions=()
	mapfile -t functions < <(
		declare -F | awk '{print $3}'
		grep -h -o -E "^\s*function\s+([a-zA-Z0-9_]+)\s*\(\)" ~/.bashrc ~/Shellscripts/* 2>/dev/null | sed 's/.*function\s\+\([a-zA-Z0-9_]\+\).*/\1/'
	)

	# Capture Git aliases correctly
	local git_aliases=()
	mapfile -t git_aliases < <(git config --get-regexp '^alias\.' | awk '{print $1}' | sed 's/^alias\.//')

	# Combine names
	local names=("${aliases[@]}" "${functions[@]}" "${git_aliases[@]}")

	# Gera a lista de sugestões para a autocompletação
	COMPREPLY=()
	for name in "${names[@]}"; do
		if [[ "$name" == "${COMP_WORDS[1]}"* ]]; then
			COMPREPLY+=("$name")
		fi
	done

	# Handle case where there is only one unique name and it matches the completion word
	if [[ ${#COMPREPLY[@]} -eq 1 && "${COMPREPLY[0]}" == "${COMP_WORDS[1]}" ]]; then
		COMPREPLY=() # Clear the suggestion
	fi

	# Prevent Bash from treating an exact match as complete
	compopt -o nospace
}

# Função para abrir um arquivo no Neovim na linha correspondente ao alias ou função
open_in_nvim() {
	local name="$1"
	local line_number
	local found=false

	check_bash_alias "$name" && return
	check_bash_function "$name" && return
	check_shellscripts_function "$name" && return
	check_git_alias "$name" && return

	if [[ $found == false ]]; then
		echo "Nenhum alias ou função chamado '$name' encontrado."
	fi
}

# Função para verificar se é um alias do bash
check_bash_alias() {
	local name="$1"
	if grep -q "^alias $name=" ~/.bashrc; then
		local line_number
		line_number=$(grep -n "^alias $name=" ~/.bashrc | cut -d: -f1)
		nvim "+$line_number" ~/.bashrc
		found=true
		return 0
	fi
	return 1
}

# Função para verificar definições de funções em .bashrc
check_bash_function() {
	local name="$1"
	if grep -s -q -E "^\s*function\s+$name\s*\(\)|^\s*$name\s*\(\)" ~/.bashrc 2>/dev/null; then
		local line_number
		line_number=$(grep -n -E "^\s*function\s+$name\s*\(\)|^\s*$name\s*\(\)" ~/.bashrc | cut -d: -f1)
		nvim "+$line_number" ~/.bashrc
		found=true
		return 0
	fi
	return 1
}

# Função para procurar funções em arquivos no ~/Shellscripts
check_shellscripts_function() {
	local name="$1"
	local file_match
	file_match=$(find ~/Shellscripts -type f -exec grep -s -l -E "^\s*function\s+$name\s*\(\)|^\s*$name\s*\(\)" {} + 2>/dev/null | head -n 1)

	if [[ -n $file_match ]]; then
		local match
		match=$(grep -n -E "^\s*function\s+$name\s*\(\)|^\s*$name\s*\(\)" "$file_match" | head -n 1)
		local line_number
		line_number=$(echo "$match" | cut -d: -f1)
		nvim "+$line_number" "$file_match"
		found=true
		return 0
	fi
	return 1
}

# Função para verificar se é um alias do git
check_git_alias() {
	local name="$1"
	if git config --get "alias.$name" >/dev/null; then
		local line_number
		line_number=$(grep -n "^\\s*${name} = " ~/.gitconfig | cut -d: -f1)
		nvim "+$line_number" ~/.gitconfig
		found=true
		return 0
	fi
	return 1
}

# Verifica se um argumento foi passado
if [[ $# -eq 1 ]]; then
	open_in_nvim "$1"
fi

# Ativa a autocompletação para o comando 'pesquisa.sh'
complete -F _autocomplete_names pesquisa.sh
