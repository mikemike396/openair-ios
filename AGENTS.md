Keep answers short unless otherwise requested. Be direct and unsparing.

Do not run visual simulator checks for non-UI changes. For persistence,
domain logic, settings defaults, migrations, and other non-visual code paths,
prefer focused unit tests or build checks. Use simulator UI or screenshot
verification only when the change affects visible UI, navigation, layout,
rendering, or user interaction.
