SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.RECIPEPREFIX := >
.SILENT:

.PHONY: help lint lint-md lint-sh lint-ps1 test test-installers test-quality-normalizer test-repo-metrics test-feature-gap-docs test-feature-gap-candidates test-test-gap-docs test-refactor-candidates check

help:
>printf '%s\n' \
>  'Available targets:' \
>  '  make lint   - Run repository linters and syntax checks' \
>  '  make test   - Run lightweight smoke tests for installer entrypoints' \
>  '  make test-quality-normalizer - Validate sample-driven quality signal normalization' \
>  '  make test-repo-metrics - Validate repository file/module metric collection' \
>  '  make test-feature-gap-docs - Validate feature-gap area documentation output' \
>  '  make test-feature-gap-candidates - Validate goal-aligned small feature proposal extraction' \
>  '  make test-test-gap-docs - Validate test-gap area documentation output' \
>  '  make test-refactor-candidates - Validate goal-aligned refactor candidate extraction' \
>  '  make check  - Run lint + test'

lint: lint-md lint-sh lint-ps1

lint-md:
>if command -v markdownlint-cli2 >/dev/null 2>&1; then \
>  echo '== markdownlint-cli2 =='; \
>  find . \( -path './.git' -o -path './.codex' \) -prune -o -type f -name '*.md' -print0 | xargs -0 markdownlint-cli2; \
>elif command -v markdownlint >/dev/null 2>&1; then \
>  echo '== markdownlint =='; \
>  find . \( -path './.git' -o -path './.codex' \) -prune -o -type f -name '*.md' -print0 | xargs -0 markdownlint; \
>else \
>  echo 'skip: markdownlint-cli2 or markdownlint not installed'; \
>fi

lint-sh:
>echo '== bash -n =='; \
>find . \( -path './.git' -o -path './.codex' \) -prune -o -type f -name '*.sh' -print0 | xargs -0 -I{} bash -n "{}"
>if command -v shellcheck >/dev/null 2>&1; then \
>  echo '== shellcheck =='; \
>  find . \( -path './.git' -o -path './.codex' \) -prune -o -type f -name '*.sh' -print0 | xargs -0 shellcheck; \
>else \
>  echo 'skip: shellcheck not installed'; \
>fi

lint-ps1:
>if command -v pwsh >/dev/null 2>&1; then \
>  echo '== PowerShell parse =='; \
>  pwsh -NoLogo -NoProfile -Command '$$ErrorActionPreference = "Stop"; $$files = Get-ChildItem -Recurse -File -Filter *.ps1 | Where-Object { $$_.FullName -notmatch "[/\\\\]\\.git([/\\\\]|$$)" -and $$_.FullName -notmatch "[/\\\\]\\.codex([/\\\\]|$$)" }; $$parseErrors = @(); foreach ($$file in $$files) { $$tokens = $$null; $$errors = $$null; [System.Management.Automation.Language.Parser]::ParseFile($$file.FullName, [ref]$$tokens, [ref]$$errors) | Out-Null; if ($$errors) { $$parseErrors += $$errors } }; if ($$parseErrors.Count -gt 0) { $$parseErrors | ForEach-Object { Write-Error ("$$($$_.Extent.File):$$($$_.Extent.StartLineNumber): $$($$_.Message)") }; exit 1 }; if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) { $$issues = Invoke-ScriptAnalyzer -Path . -Recurse; if ($$issues) { $$issues | Format-Table -AutoSize | Out-String | Write-Host; exit 1 } } else { Write-Host "skip: PSScriptAnalyzer not installed" }'; \
>elif command -v powershell >/dev/null 2>&1; then \
>  echo '== Windows PowerShell parse =='; \
>  powershell -NoLogo -NoProfile -Command '$$ErrorActionPreference = "Stop"; $$files = Get-ChildItem -Recurse -File -Filter *.ps1 | Where-Object { $$_.FullName -notmatch "[/\\\\]\\.git([/\\\\]|$$)" -and $$_.FullName -notmatch "[/\\\\]\\.codex([/\\\\]|$$)" }; $$parseErrors = @(); foreach ($$file in $$files) { $$tokens = $$null; $$errors = $$null; [System.Management.Automation.Language.Parser]::ParseFile($$file.FullName, [ref]$$tokens, [ref]$$errors) | Out-Null; if ($$errors) { $$parseErrors += $$errors } }; if ($$parseErrors.Count -gt 0) { $$parseErrors | ForEach-Object { Write-Error ("$$($$_.Extent.File):$$($$_.Extent.StartLineNumber): $$($$_.Message)") }; exit 1 }; if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) { $$issues = Invoke-ScriptAnalyzer -Path . -Recurse; if ($$issues) { $$issues | Format-Table -AutoSize | Out-String | Write-Host; exit 1 } } else { Write-Host "skip: PSScriptAnalyzer not installed" }'; \
>else \
>  echo 'skip: pwsh or powershell not installed'; \
>fi

test: test-installers test-quality-normalizer test-repo-metrics test-feature-gap-docs test-feature-gap-candidates test-test-gap-docs test-refactor-candidates

test-installers:
>echo '== bash installer smoke =='
>bash installer/CodexMultiAgent.sh --help >/dev/null

test-quality-normalizer:
>if command -v python3 >/dev/null 2>&1; then \
>  echo '== quality signal normalization ==' ; \
>  store_file="$$(mktemp)"; \
>  repo_store_file="$$(mktemp)"; \
>  latest_file="$$(mktemp)"; \
>  summary_file="$$(mktemp)"; \
>  tmpdir="$$(mktemp -d)"; \
>  trap 'rm -f "$$store_file" "$$repo_store_file" "$$latest_file" "$$summary_file"; python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$$tmpdir"' EXIT; \
>  python3 scripts/normalize_quality_signals.py --input examples/quality_signal_samples.json >/dev/null; \
>  python3 scripts/normalize_quality_signals.py --input examples/quality_signal_samples.json --history "$$store_file" --store >/dev/null; \
>  python3 scripts/normalize_quality_signals.py --history "$$store_file" --query latest >/dev/null; \
>  python3 scripts/normalize_quality_signals.py --history "$$store_file" --query summary >/dev/null; \
>  git -C "$$tmpdir" init >/dev/null; \
>  git -C "$$tmpdir" config user.name 'Fixture User'; \
>  git -C "$$tmpdir" config user.email 'fixture@example.com'; \
>  printf '%s\n' 'def alpha(flag):' '    if flag:' '        return 1' '    return 0' > "$$tmpdir/a.py"; \
>  printf '%s\n' 'def beta(flag):' '    if flag:' '        return 1' '    return 0' > "$$tmpdir/b.py"; \
>  printf '%s\n' '#!/bin/sh' 'run() {' '  echo ok' '}' > "$$tmpdir/c.sh"; \
>  env GIT_AUTHOR_DATE='2026-01-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-01-01T00:00:00+00:00' git -C "$$tmpdir" add a.py b.py c.sh && env GIT_AUTHOR_DATE='2026-01-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-01-01T00:00:00+00:00' git -C "$$tmpdir" commit -m 'feat: add repo fixture files' >/dev/null; \
>  printf '%s\n' '' '# churn marker' >> "$$tmpdir/a.py"; \
>  env GIT_AUTHOR_DATE='2026-02-15T00:00:00+00:00' GIT_COMMITTER_DATE='2026-02-15T00:00:00+00:00' git -C "$$tmpdir" add a.py && env GIT_AUTHOR_DATE='2026-02-15T00:00:00+00:00' GIT_COMMITTER_DATE='2026-02-15T00:00:00+00:00' git -C "$$tmpdir" commit -m 'fix: touch hotspot fixture' >/dev/null; \
>  python3 scripts/collect_repo_metrics.py --root "$$tmpdir" --paths a.py b.py c.sh --pretty > "$$tmpdir/repo-metrics.json"; \
>  python3 scripts/normalize_quality_signals.py --input "$$tmpdir/repo-metrics.json" --pretty > "$$tmpdir/repo-quality.json"; \
>  python3 scripts/normalize_quality_signals.py --input "$$tmpdir/repo-metrics.json" --history "$$repo_store_file" --store >/dev/null; \
>  python3 scripts/normalize_quality_signals.py --history "$$repo_store_file" --query latest > "$$latest_file"; \
>  python3 scripts/normalize_quality_signals.py --history "$$repo_store_file" --query summary > "$$summary_file"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['analysis_kind'] == 'repo_metrics', payload; assert payload['result_count'] == 3, payload; assert payload['summary']['file_count'] == 3, payload['summary']; assert payload['summary']['priority_grade_distribution']['C'] >= 1, payload['summary']; top=payload['hotspots'][0]; assert top['path'] == 'a.py', top; ranked=payload['results'][0]; assert ranked['path'] == 'a.py', ranked; assert ranked['quality_signal']['priority_rank'] == 1, ranked; assert ranked['quality_signal']['priority_grade'] in {'B', 'C'}, ranked; assert ranked['quality_signal']['axis_breakdown']['duplication_pressure']['score'] > 0, ranked; assert ranked['quality_signal']['axis_breakdown']['change_pressure']['score'] > 0, ranked; print('repo metric normalization fixture passed')" "$$tmpdir/repo-quality.json"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); latest=payload['latest']; assert latest['analysis']['analysis_kind'] == 'repo_metrics', latest; print('repo metric history latest fixture passed')" "$$latest_file"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['analysis_kind_occurrences']['repo_metrics'] == 1, payload; print('repo metric history summary fixture passed')" "$$summary_file"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

test-repo-metrics:
>if command -v python3 >/dev/null 2>&1; then \
>  if ! command -v git >/dev/null 2>&1; then \
>    echo 'skip: git not installed'; \
>    exit 0; \
>  fi; \
>  echo '== repository metrics ==' ; \
>  tmpdir="$$(mktemp -d)"; \
>  trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$$tmpdir"' EXIT; \
>  git -C "$$tmpdir" init >/dev/null; \
>  git -C "$$tmpdir" config user.name 'Fixture User'; \
>  git -C "$$tmpdir" config user.email 'fixture@example.com'; \
>  printf '%s\n' '# sample comment' '' 'class Demo:' '    pass' '' 'def run(flag):' '    if flag:' '        return 1' '    return 0' > "$$tmpdir/sample.py"; \
>  printf '%s\n' '#!/bin/sh' 'say_hi() {' '  if [ "$$1" = "x" ]; then' '    echo hi' '  fi' '}' > "$$tmpdir/sample.sh"; \
>  env GIT_AUTHOR_DATE='2026-01-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-01-01T00:00:00+00:00' git -C "$$tmpdir" add sample.py sample.sh && env GIT_AUTHOR_DATE='2026-01-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-01-01T00:00:00+00:00' git -C "$$tmpdir" commit -m 'feat: add fixture base' >/dev/null; \
>  printf '%s\n' 'def run(flag):' '    if flag:' '        return 1' '    return 0' > "$$tmpdir/sample_copy.py"; \
>  env GIT_AUTHOR_DATE='2026-02-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-02-01T00:00:00+00:00' git -C "$$tmpdir" add sample_copy.py && env GIT_AUTHOR_DATE='2026-02-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-02-01T00:00:00+00:00' git -C "$$tmpdir" commit -m 'feat: add duplicate fixture' >/dev/null; \
>  printf '%s\n' '' '# tuned branch' >> "$$tmpdir/sample.py"; \
>  env GIT_AUTHOR_DATE='2026-03-15T12:00:00+00:00' GIT_COMMITTER_DATE='2026-03-15T12:00:00+00:00' git -C "$$tmpdir" add sample.py && env GIT_AUTHOR_DATE='2026-03-15T12:00:00+00:00' GIT_COMMITTER_DATE='2026-03-15T12:00:00+00:00' git -C "$$tmpdir" commit -m 'fix: touch python fixture' >/dev/null; \
>  python3 scripts/collect_repo_metrics.py --root "$$tmpdir" --paths sample.py sample_copy.py sample.sh --pretty > "$$tmpdir/out.json"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['schema_version'] == 1, payload; assert payload['summary']['file_count'] == 3, payload['summary']; history=payload['summary']['change_frequency']; assert history['files_with_history'] == 3, history; assert history['max_commit_count'] == 2, history; assert history['hotspots'][0]['path'] == 'sample_copy.py', history; assert history['hotspots'][0]['commit_count'] == 2, history; assert payload['duplication']['group_count'] == 1, payload['duplication']; groups=payload['duplication']['groups']; assert len(groups) == 1, groups; group=groups[0]; assert group['normalized_line_count'] == 4, group; assert group['occurrence_count'] == 2, group; module_paths={entry['path'] for entry in group['modules']}; assert module_paths == {'sample.py', 'sample_copy.py'}, group; files={entry['path']: entry for entry in payload['files']}; py=files['sample.py']; py_copy=files['sample_copy.py']; sh=files['sample.sh']; assert py['language'] == 'python', py; assert py['module_size']['total_lines'] == 11, py; assert py['module_size']['comment_lines'] == 2, py; assert py['complexity']['class_like_blocks'] == 1, py; assert py['complexity']['function_like_blocks'] == 1, py; assert py['complexity']['decision_points'] == 1, py; assert py['complexity']['cyclomatic_estimate'] == 2, py; assert py['duplication']['group_count'] == 1, py; assert py['duplication']['duplicated_line_instances'] == 4, py; assert py['change_frequency']['commit_count'] == 2, py; assert py['change_frequency']['author_count'] == 1, py; assert py['change_frequency']['first_commit_at'] == '2026-01-01T00:00:00Z', py; assert py['change_frequency']['last_commit_at'] == '2026-03-15T12:00:00Z', py; assert py['change_frequency']['active_days'] == 73, py; assert py['change_frequency']['commits_per_30_days'] == 0.82, py; assert py_copy['duplication']['group_count'] == 1, py_copy; assert py_copy['duplication']['max_duplicate_block_lines'] == 4, py_copy; assert py_copy['change_frequency']['commit_count'] == 2, py_copy; assert py_copy['change_frequency']['first_commit_at'] == '2026-01-01T00:00:00Z', py_copy; assert py_copy['change_frequency']['last_commit_at'] == '2026-02-01T00:00:00Z', py_copy; assert py_copy['change_frequency']['active_days'] == 31, py_copy; assert py_copy['change_frequency']['commits_per_30_days'] == 1.94, py_copy; assert sh['language'] == 'shell', sh; assert sh['complexity']['function_like_blocks'] == 1, sh; assert sh['complexity']['decision_points'] == 1, sh; assert sh['complexity']['cyclomatic_estimate'] == 2, sh; assert sh['duplication']['group_count'] == 0, sh; assert sh['change_frequency']['commit_count'] == 1, sh; print('repository metrics fixture passed')" "$$tmpdir/out.json"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

test-feature-gap-docs:
>if command -v python3 >/dev/null 2>&1; then \
>  echo '== feature gap area docs ==' ; \
>  json_file="$$(mktemp)"; \
>  md_file="$$(mktemp)"; \
>  trap 'rm -f "$$json_file" "$$md_file"' EXIT; \
>  python3 scripts/extract_feature_gap_candidates.py --root . --pretty > "$$json_file"; \
>  python3 scripts/extract_feature_gap_candidates.py --root . --format markdown > "$$md_file"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['schema_version'] == 3, payload; assert 'documented_feature_gap_count' in payload, payload; assert payload['documented_feature_gap_count'] >= 1, payload; installer=[area for area in payload['areas'] if area['area_id'] == 'installer']; assert installer, payload['areas']; documented=installer[0]['documented_feature_gaps']; assert documented, installer[0]; entry=documented[0]; assert entry['evidence']['summary'], entry; assert entry['current_status']['summary'], entry; assert entry['expected_impact']['summary'], entry; print('feature gap json fixture passed')" "$$json_file"; \
>  python3 -c "import sys; from pathlib import Path; generated=Path(sys.argv[1]).read_text(encoding='utf-8'); committed=Path('docs/FEATURE_GAP_AREAS.md').read_text(encoding='utf-8'); assert generated == committed, 'generated markdown differs from docs/FEATURE_GAP_AREAS.md'; assert '예상 영향도:' in generated, generated; assert '현재 상태:' in generated, generated; print('feature gap markdown fixture passed')" "$$md_file"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

test-feature-gap-candidates:
>if command -v python3 >/dev/null 2>&1; then \
>  echo '== feature gap candidates ==' ; \
>  tmpdir="$$(mktemp -d)"; \
>  trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$$tmpdir"' EXIT; \
>  mkdir -p "$$tmpdir/docs"; \
>  printf '%s\n' 'def build_report(data):' '    # TODO hook report verification output' '    raise NotImplementedError(\"report output not implemented\")' > "$$tmpdir/report_tool.py"; \
>  printf '%s\n' 'report output placeholder for later docs sync' > "$$tmpdir/docs/report_guide.py"; \
>  python3 scripts/extract_feature_gap_candidates.py --root "$$tmpdir" --pretty > "$$tmpdir/out.json"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['schema_version'] == 3, payload; assert payload['small_feature_candidate_count'] >= 1, payload; first=payload['small_feature_candidates'][0]; assert first['candidate_kind'] == 'small_feature', first; assert first['common_axes']['goal_alignment'] == 'pass', first; assert first['small_feature_rubric']['goal_alignment'] >= 2, first; assert first['small_feature_rubric']['value'] >= 2, first; assert isinstance(first['implementation_scope'], list) and first['implementation_scope'], first; assert isinstance(first['selection_rationale'], list) and first['selection_rationale'], first; assert first['user_value'], first; print('feature gap candidate fixture passed')" "$$tmpdir/out.json"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

test-test-gap-docs:
>if command -v python3 >/dev/null 2>&1; then \
>  echo '== test gap area docs ==' ; \
>  json_file="$$(mktemp)"; \
>  md_file="$$(mktemp)"; \
>  trap 'rm -f "$$json_file" "$$md_file"' EXIT; \
>  python3 scripts/extract_test_gap_candidates.py --root . --pretty > "$$json_file"; \
>  python3 scripts/extract_test_gap_candidates.py --root . --format markdown > "$$md_file"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['schema_version'] == 1, payload; assert payload['test_file_count'] == 0, payload; assert payload['finding_count'] >= 4, payload; categories={item['category'] for item in payload['findings']}; assert {'missing_tests','coverage_gap','flaky_risk','verification_gap'}.issubset(categories), categories; first=payload['findings'][0]; assert first['evidence'], first; assert first['scenario'], first; print('test gap json fixture passed')" "$$json_file"; \
>  python3 -c "import sys; from pathlib import Path; generated=Path(sys.argv[1]).read_text(encoding='utf-8'); committed=Path('docs/TEST_GAP_AREAS.md').read_text(encoding='utf-8'); assert generated == committed, 'generated markdown differs from docs/TEST_GAP_AREAS.md'; assert '시나리오:' in generated, generated; assert '근거 판단:' in generated, generated; print('test gap markdown fixture passed')" "$$md_file"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

test-refactor-candidates:
>if command -v python3 >/dev/null 2>&1; then \
>  echo '== refactor candidates ==' ; \
>  json_file="$$(mktemp)"; \
>  md_file="$$(mktemp)"; \
>  trap 'rm -f "$$json_file" "$$md_file"' EXIT; \
>  python3 scripts/extract_refactor_candidates.py --root . --pretty > "$$json_file"; \
>  python3 scripts/extract_refactor_candidates.py --root . --format markdown > "$$md_file"; \
>  python3 -c "import json,sys; payload=json.load(open(sys.argv[1], 'r', encoding='utf-8')); assert payload['schema_version'] == 1, payload; assert payload['refactor_candidate_count'] >= 1, payload; first=payload['refactor_candidates'][0]; assert first['candidate_kind'] == 'refactor', first; assert isinstance(first['problem_signals'], list) and first['problem_signals'], first; assert isinstance(first['expected_improvement'], list) and first['expected_improvement'], first; assert isinstance(first['selection_rationale'], list) and first['selection_rationale'], first; assert isinstance(first['evidence_locations'], list) and first['evidence_locations'], first; print('refactor candidate json fixture passed')" "$$json_file"; \
>  python3 -c "import sys; from pathlib import Path; generated=Path(sys.argv[1]).read_text(encoding='utf-8'); committed=Path('docs/REFACTOR_CANDIDATES.md').read_text(encoding='utf-8'); assert generated == committed, 'generated markdown differs from docs/REFACTOR_CANDIDATES.md'; assert '문제 징후:' in generated, generated; assert '개선 기대효과:' in generated, generated; assert '선정 근거:' in generated, generated; print('refactor candidate markdown fixture passed')" "$$md_file"; \
>else \
>  echo 'skip: python3 not installed'; \
>fi

check: lint test
