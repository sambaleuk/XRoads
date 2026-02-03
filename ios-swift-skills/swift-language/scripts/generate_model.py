#!/usr/bin/env python3
"""
Swift Model Generator

Generates Swift struct models from JSON-like specifications.
Useful for quickly creating data models with Codable conformance.

Usage:
    python3 generate_model.py --name User --properties "name:String,age:Int,email:String?"
"""

import argparse
import sys
from typing import List, Tuple


def parse_property(prop_str: str) -> Tuple[str, str, bool]:
    """
    Parse a property string like 'name:String' or 'email:String?'
    Returns (name, type, is_optional)
    """
    parts = prop_str.split(':')
    if len(parts) != 2:
        raise ValueError(f"Invalid property format: {prop_str}. Expected 'name:Type'")

    name = parts[0].strip()
    type_str = parts[1].strip()

    is_optional = type_str.endswith('?')
    if is_optional:
        type_str = type_str[:-1]

    return name, type_str, is_optional


def generate_swift_model(
    name: str,
    properties: List[Tuple[str, str, bool]],
    codable: bool = True,
    identifiable: bool = False,
    with_init: bool = True
) -> str:
    """Generate Swift struct model code"""

    lines = []

    # Struct declaration
    protocols = []
    if codable:
        protocols.append("Codable")
    if identifiable:
        protocols.append("Identifiable")

    protocol_str = f": {', '.join(protocols)}" if protocols else ""
    lines.append(f"struct {name}{protocol_str} {{")

    # Properties
    for prop_name, prop_type, is_optional in properties:
        optional_marker = "?" if is_optional else ""
        lines.append(f"    let {prop_name}: {prop_type}{optional_marker}")

    # Custom initializer (if requested)
    if with_init and properties:
        lines.append("")
        lines.append("    // MARK: - Initialization")
        lines.append("")

        # Init signature
        params = []
        for prop_name, prop_type, is_optional in properties:
            optional_marker = "?" if is_optional else ""
            default = " = nil" if is_optional else ""
            params.append(f"{prop_name}: {prop_type}{optional_marker}{default}")

        init_signature = f"    init({', '.join(params)}) {{"
        lines.append(init_signature)

        # Init body
        for prop_name, _, _ in properties:
            lines.append(f"        self.{prop_name} = {prop_name}")

        lines.append("    }")

    lines.append("}")

    return "\n".join(lines)


def generate_example_usage(name: str, properties: List[Tuple[str, str, bool]]) -> str:
    """Generate example usage code"""

    lines = [
        "",
        "// MARK: - Example Usage",
        "",
        f"// Create instance",
    ]

    # Example instantiation
    params = []
    for prop_name, prop_type, is_optional in properties:
        if prop_type == "String":
            value = f'"{prop_name}_value"'
        elif prop_type == "Int":
            value = "42"
        elif prop_type == "Double" or prop_type == "Float":
            value = "3.14"
        elif prop_type == "Bool":
            value = "true"
        else:
            value = f"{prop_type}()" if not is_optional else "nil"

        params.append(f"{prop_name}: {value}")

    lines.append(f"let {name.lower()} = {name}(")
    for i, param in enumerate(params):
        comma = "," if i < len(params) - 1 else ""
        lines.append(f"    {param}{comma}")
    lines.append(")")

    # JSON encoding example
    lines.extend([
        "",
        "// Encode to JSON",
        "let encoder = JSONEncoder()",
        "encoder.outputFormatting = .prettyPrinted",
        "if let jsonData = try? encoder.encode(user),",
        "   let jsonString = String(data: jsonData, encoding: .utf8) {",
        "    print(jsonString)",
        "}",
        "",
        "// Decode from JSON",
        "let decoder = JSONDecoder()",
        "if let decoded = try? decoder.decode(User.self, from: jsonData) {",
        "    print(decoded)",
        "}",
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate Swift struct models",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic model
  python3 generate_model.py --name User --properties "name:String,age:Int,email:String?"

  # Model with ID
  python3 generate_model.py --name Product --properties "id:UUID,name:String,price:Double" --identifiable

  # Without custom init
  python3 generate_model.py --name Config --properties "apiKey:String,timeout:Int" --no-init
        """
    )

    parser.add_argument(
        "--name",
        required=True,
        help="Name of the struct"
    )

    parser.add_argument(
        "--properties",
        required=True,
        help="Comma-separated properties (format: name:Type or name:Type? for optional)"
    )

    parser.add_argument(
        "--no-codable",
        action="store_true",
        help="Don't add Codable conformance"
    )

    parser.add_argument(
        "--identifiable",
        action="store_true",
        help="Add Identifiable conformance"
    )

    parser.add_argument(
        "--no-init",
        action="store_true",
        help="Don't generate custom initializer"
    )

    parser.add_argument(
        "--example",
        action="store_true",
        help="Include example usage"
    )

    parser.add_argument(
        "--output",
        help="Output file path (default: stdout)"
    )

    args = parser.parse_args()

    # Parse properties
    try:
        properties = [
            parse_property(prop.strip())
            for prop in args.properties.split(',')
        ]
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Generate model
    model_code = generate_swift_model(
        name=args.name,
        properties=properties,
        codable=not args.no_codable,
        identifiable=args.identifiable,
        with_init=not args.no_init
    )

    # Add example if requested
    if args.example:
        model_code += generate_example_usage(args.name, properties)

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(model_code + "\n")
        print(f"✅ Generated {args.name}.swift at {args.output}", file=sys.stderr)
    else:
        print(model_code)


if __name__ == "__main__":
    main()
