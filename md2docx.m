function md2docx(mdPath, docxPath)
% md2docx - Lightweight Markdown -> Word (.docx) via HTML + Word COM.
% Handles headings, tables, bold/italic, horizontal rules, inline math
% (simple LaTeX), block equations (kept as raw LaTeX in monospace for the
% author to re-typeset), and embeds figures referenced as `figN...png`.
% Office (Word) must be installed.

if isempty(regexp(docxPath, '^[A-Za-z]:', 'once'))
    docxPath = fullfile(pwd, docxPath);
end
docxPath = strrep(char(docxPath), '/', '\');

txt = fileread(mdPath);
lines = string(splitlines(string(txt)));
baseDir = fileparts(mdPath);

H = strings(0,1);
H(end+1) = "<html><head><meta charset=""UTF-8""><style>" + ...
    "body{font-family:'Times New Roman',serif;font-size:11pt;line-height:1.3;}" + ...
    "table{border-collapse:collapse;margin:6pt 0;}" + ...
    "td,th{border:0.5pt solid #000;padding:2pt 6pt;font-size:10pt;}" + ...
    "th{background:#eee;}h1{font-size:16pt;}h2{font-size:13pt;}h3{font-size:12pt;}" + ...
    "code{font-family:Consolas,monospace;font-size:9.5pt;}</style></head><body>";

i = 1; n = numel(lines);
while i <= n
    s = strtrim(lines(i));
    if s == "", i = i + 1; continue; end

    if startsWith(s, "### "), H(end+1) = "<h3>" + inl(extractAfter(s,4)) + "</h3>"; i=i+1; continue; end
    if startsWith(s, "## "),  H(end+1) = "<h2>" + inl(extractAfter(s,3)) + "</h2>"; i=i+1; continue; end
    if startsWith(s, "# "),   H(end+1) = "<h1>" + inl(extractAfter(s,2)) + "</h1>"; i=i+1; continue; end
    if startsWith(s, "---"),  H(end+1) = "<hr>"; i=i+1; continue; end

    % ---- block equation $$ ... $$ ----
    if startsWith(s, "$$")
        eq = extractAfter(s, 2);
        if endsWith(s, "$$") && strlength(s) > 2
            eq = extractBefore(eq, strlength(eq)-1);
            i = i + 1;
        else
            i = i + 1;
            while i <= n && strtrim(lines(i)) ~= "$$"
                eq = eq + " " + strtrim(lines(i)); i = i + 1;
            end
            i = i + 1; % consume closing $$
        end
        lbl = "";
        t = regexp(eq, '\\tag\{([^}]*)\}', 'tokens', 'once');
        if ~isempty(t), lbl = "  (" + t{1} + ")"; end
        eq = regexprep(eq, '\\tag\{[^}]*\}', '');
        eq = strtrim(eq);
        H(end+1) = "<p style='margin-left:2.5em;font-family:Consolas,monospace;font-size:10pt;'>" + ...
                   esc(eq) + esc(lbl) + "</p>";
        continue;
    end

    % ---- table ----
    if startsWith(s, "|")
        tbl = strings(0,1);
        while i <= n && startsWith(strtrim(lines(i)), "|")
            tbl(end+1) = strtrim(lines(i)); i = i + 1; %#ok<AGROW>
        end
        H(end+1) = tableHtml(tbl);
        continue;
    end

    % ---- paragraph ----
    H(end+1) = "<p>" + inl(s) + "</p>";
    img = regexp(s, '(fig\d[\w\-]*\.png)', 'tokens', 'once');
    if ~isempty(img)
        p = strrep(fullfile(baseDir, img{1}), '\', '/');
        H(end+1) = "<p><img src='" + p + "' style='width:6.4in'/></p>"; %#ok<AGROW>
    end
    i = i + 1;
end
H(end+1) = "</body></html>";

htmlPath = [tempname '.html'];
fid = fopen(htmlPath, 'w', 'n', 'UTF-8');
fprintf(fid, '%s', strjoin(H, newline));
fclose(fid);

% ---- Word COM ----
word = actxserver('Word.Application');
cleanupObj = onCleanup(@() word.Quit());
word.Visible = false;
word.DisplayAlerts = 0;
doc = word.Documents.Open(htmlPath);
if exist(docxPath, 'file'), delete(docxPath); end
doc.SaveAs2(docxPath, 16);   % wdFormatDocumentDefault = .docx
doc.Close(0);
delete(htmlPath);
fprintf('Wrote %s\n', docxPath);
end

% ------------------------------------------------------------------------
function h = tableHtml(rows)
h = "<table>";
for r = 1:numel(rows)
    if r == 2, continue; end           % separator row
    cells = split(rows(r), "|");
    cells = cells(2:end-1);            % drop outer empties
    tag = "td"; if r == 1, tag = "th"; end
    h = h + "<tr>";
    for c = 1:numel(cells)
        h = h + "<" + tag + ">" + inl(strtrim(cells(c))) + "</" + tag + ">";
    end
    h = h + "</tr>";
end
h = h + "</table>";
end

% ------------------------------------------------------------------------
function out = inl(s)
% inline: protect code spans, escape &, simple math, bold/italic
s = string(s);
codes = strings(0,1);
while true
    t = regexp(s, '`([^`]*)`', 'tokens', 'once');
    if isempty(t), break; end
    codes(end+1) = string(t{1}); %#ok<AGROW>
    s = regexprep(s, '`[^`]*`', "@@CODE" + numel(codes) + "@@", 'once');
end
s = replace(s, "&", "&amp;");
s = mathify(s);
s = regexprep(s, '\*\*(.*?)\*\*', '<b>$1</b>');
s = regexprep(s, '\*(.*?)\*', '<i>$1</i>');
for k = 1:numel(codes)
    s = replace(s, "@@CODE" + k + "@@", "<code>" + esc(codes(k)) + "</code>");
end
out = s;
end

% ------------------------------------------------------------------------
function s = mathify(s)
s = replace(s, "$", "");
s = regexprep(s, '\\boxed\{', '');
s = regexprep(s, '\\text\{([^}]*)\}', '$1');
s = regexprep(s, '\\frac\{([^{}]*)\}\{([^{}]*)\}', '($1)/($2)');
s = regexprep(s, '\^\{([^}]*)\}', '<sup>$1</sup>');
s = regexprep(s, '_\{([^}]*)\}', '<sub>$1</sub>');
s = regexprep(s, '\^([A-Za-z0-9])', '<sup>$1</sup>');
s = regexprep(s, '_([A-Za-z0-9])', '<sub>$1</sub>');
reps = { '\\bar\\rho','ρ̄'; '\\mu','μ'; '\\rho','ρ'; '\\lambda','λ'; ...
         '\\Delta','Δ'; '\\sigma','σ'; '\\sum','Σ'; '\\dots','…'; ...
         '\\approx','≈'; '\\to','→'; '\\in','∈'; '\\times','×'; ...
         '\\,',' '; '\\;',' ' };
for k = 1:size(reps,1)
    s = regexprep(s, reps{k,1}, reps{k,2});
end
s = regexprep(s, '\\([A-Za-z]+)', '$1');   % drop remaining \cmd -> cmd
s = replace(s, "{", ""); s = replace(s, "}", ""); s = replace(s, "\", "");
end

% ------------------------------------------------------------------------
function s = esc(s)
s = string(s);
s = replace(s, "&", "&amp;");
s = replace(s, "<", "&lt;");
s = replace(s, ">", "&gt;");
end
