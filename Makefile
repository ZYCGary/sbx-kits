# Every kit is listed explicitly. Add a line here when you add a kit.
.PHONY: validate

validate:
	sbx kit validate ./laravel-sail/
	sbx kit validate ./pnpm/
	sbx kit validate ./ccstatusline/
	sbx kit validate ./rtk/claude/
	sbx kit validate ./i-have-adhd/claude/
	sbx kit validate ./caveman/claude/
	sbx kit validate ./mattpocock-skills/claude/
