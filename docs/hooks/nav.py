from typing import cast

from mkdocs.config.defaults import MkDocsConfig
from mkdocs.structure import StructureItem
from mkdocs.structure.nav import Section
from mkdocs.structure.pages import Page
from mkdocs.utils import normalize_url


# TODO: replace this wih on_page_markdown in order to replace the markdown by something else
def on_post_page(output: str, *, page: Page, config: MkDocsConfig):
    if '{nav}' in output and page.parent:
        children = page.parent.children
        siblings = [child for child in children if child is not page]
        return output.replace('{nav}', _format_links(siblings, page, config))

def _format_links(items: list[StructureItem], page: Page, config: MkDocsConfig):
    result = '<ul>'

    for item in items:
        result += '<li>'

        if item.is_section and item.title is not None:
            result += item.title
            if item.is_section:
                section = cast(Section, item)
                result += _format_links(section.children, page, config)
        elif item.is_page and item.title is not None:
            item = cast(Page, item)
            url = normalize_url(item.url, page)
            result += f'<a href="{url}">{item.title}</a>'
            if 'description' in item.meta:
                result += f': <span class="description">{item.meta["description"]}</span>'

        result += '</li>'

    result += '</ul>'

    return result
