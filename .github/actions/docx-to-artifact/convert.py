#!/usr/bin/env python3
"""Convert DOCX files to various artifact formats."""

import argparse
import json
import sys
from pathlib import Path
from docx import Document
import yaml


def extract_text_from_docx(docx_path):
    """Extract text content from DOCX file."""
    doc = Document(docx_path)
    return '\n'.join([para.text for para in doc.paragraphs if para.text.strip()])


def convert_to_yaml(content, output_path):
    """Convert content to YAML format."""
    data = {
        'content': content,
        'metadata': {
            'format': 'yaml',
            'generator': 'docx-to-artifact'
        }
    }
    with open(output_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False)


def convert_to_json(content, output_path):
    """Convert content to JSON format."""
    data = {
        'content': content,
        'metadata': {
            'format': 'json',
            'generator': 'docx-to-artifact'
        }
    }
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)


def convert_to_markdown(content, output_path):
    """Convert content to Markdown format."""
    with open(output_path, 'w') as f:
        f.write(f"# Document Content\n\n{content}\n")


def convert_to_python(content, output_path):
    """Convert content to Python module format."""
    with open(output_path, 'w') as f:
        f.write('"""Generated artifact from DOCX."""\n\n')
        f.write(f'CONTENT = """{content}"""\n')


def main():
    parser = argparse.ArgumentParser(description='Convert DOCX to artifacts')
    parser.add_argument('--input', required=True, help='Input DOCX file')
    parser.add_argument('--format', required=True, choices=['yaml', 'json', 'markdown', 'python'])
    parser.add_argument('--output', required=True, help='Output file (without extension)')

    args = parser.parse_args()

    try:
        content = extract_text_from_docx(args.input)

        output_path = f"{args.output}.{args.format}"
        if args.format == 'python':
            output_path = f"{args.output}.py"
        elif args.format == 'markdown':
            output_path = f"{args.output}.md"

        if args.format == 'yaml':
            convert_to_yaml(content, output_path)
        elif args.format == 'json':
            convert_to_json(content, output_path)
        elif args.format == 'markdown':
            convert_to_markdown(content, output_path)
        elif args.format == 'python':
            convert_to_python(content, output_path)

        print(f"Successfully converted to {output_path}")
        sys.exit(0)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
