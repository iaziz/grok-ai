" File: grok.vim
" Description: Vim plugin for AI-powered text completion, editing, and chat with Grok
" Author: Grok
" Version: 1.0

if exists('g:loaded_grok') || !has('python3')
  finish
endif
let g:loaded_grok = 1

" Default API endpoint (replace with xAI's actual endpoint)
if !exists('g:grok_api_endpoint')
  let g:grok_api_endpoint = 'https://api.x.ai/v1/grok'
endif

" Store API key (set via :SetGrokApiKey command)
if !exists('g:grok_api_key')
  let g:grok_api_key = ''
endif

" Command to set API key
command! -nargs=1 SetGrokApiKey let g:grok_api_key = <q-args>

" Function to get visually selected text
function! s:GetVisualSelection()
  let [line_start, col_start] = getpos("'<")[1:2]
  let [line_end, col_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  let lines[-1] = lines[-1][:col_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col_start - 1:]
  return join(lines, "\n")
endfunction

" Function to create or switch to chat buffer
function! s:OpenChatBuffer()
  if bufexists('GrokChat')
    execute 'buffer GrokChat'
  else
    execute 'new GrokChat'
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal filetype=markdown
  endif
endfunction

" Function to call Grok API
function! s:CallGrokApi(mode, prompt, selected_text) range
  if empty(g:grok_api_key)
    echohl ErrorMsg
    echom "Grok API key not set. Use :SetGrokApiKey <your-key>"
    echohl None
    return
  endif

  let prompt = a:prompt
  if empty(prompt) && empty(a:selected_text)
    echohl WarningMsg
    echom "No prompt or selected text provided"
    echohl None
    return
  endif

  " Start Python block
python3 << EOF
import vim
import json
import http.client
import urllib.parse

def call_grok_api():
    try:
        # Get variables from Vim
        endpoint = vim.eval('g:grok_api_endpoint')
        api_key = vim.eval('g:grok_api_key')
        mode = vim.eval('a:mode')
        prompt = vim.eval('prompt')
        selected_text = vim.eval('a:selected_text')

        # Parse URL
        parsed_url = urllib.parse.urlparse(endpoint)
        conn = http.client.HTTPSConnection(parsed_url.netloc)

        # Prepare request
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        body = json.dumps({
            'prompt': prompt,
            'context': selected_text if selected_text else '',
            'mode': mode  # complete, edit, or chat
        })

        # Send request
        conn.request('POST', parsed_url.path, body, headers)
        response = conn.getresponse()
        response_data = response.read().decode()

        if response.status != 200:
            vim.command('echohl ErrorMsg')
            vim.command(f'echom "Grok API request failed: {response.status}"')
            vim.command('echohl None')
            conn.close()
            return

        # Parse response
        try:
            result = json.loads(response_data).get('response', response_data)
        except json.JSONDecodeError:
            result = response_data

        # Handle response based on mode
        if mode == 'complete' or mode == 'edit':
            if mode == 'edit' and selected_text:
                # Replace selected text
                vim.command('normal! gvd')
                vim.current.buffer.append(result.split('\n'), vim.current.window.cursor[0] - 1)
            else:
                # Append completion
                vim.current.buffer.append(result.split('\n'), vim.current.window.cursor[0])
        elif mode == 'chat':
            # Display in chat buffer
            vim.command('call s:OpenChatBuffer()')
            vim.current.buffer.append([f"Prompt: {prompt}", ""] + result.split('\n') + ["---", ""])
            vim.command('normal! G')

        conn.close()

    except Exception as e:
        vim.command('echohl ErrorMsg')
        vim.command(f'echom "Error: {str(e)}"')
        vim.command('echohl None')

call_grok_api()
EOF
endfunction

" Commands for Grok interactions
command! -nargs=? -range GrokComplete call s:CallGrokApi('complete', <q-args>, s:GetVisualSelection())
command! -nargs=? -range GrokEdit call s:CallGrokApi('edit', <q-args>, s:GetVisualSelection())
command! -nargs=? -range GrokChat call s:CallGrokApi('chat', <q-args>, s:GetVisualSelection())

" Default mappings
vnoremap <silent> <Leader>gc :GrokComplete<CR>
vnoremap <silent> <Leader>ge :GrokEdit<CR>
nnoremap <silent> <Leader>gt :GrokChat<CR>

" Instructions for user
echom "Grok Plugin loaded. Set key with :SetGrokApiKey <key>. Use <Leader>gc (complete), <Leader>ge (edit), <Leader>gt (chat)"