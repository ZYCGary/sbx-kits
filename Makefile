# Every kit is listed explicitly. Add a line here when you add a kit.
# BUILDX_BUILDER: node/ builds with an OCI exporter; see CLAUDE.md.
.PHONY: validate

validate:
	BUILDX_BUILDER=sbx-kits sbx kit validate ./laravel/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./pnpm/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./ccstatusline/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./rtk-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./i-have-adhd-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./caveman-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./mattpocock-skills-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./codegraph-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./ponytail-claude/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./buf/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./node/
	BUILDX_BUILDER=sbx-kits sbx kit validate ./lsp-claude/
