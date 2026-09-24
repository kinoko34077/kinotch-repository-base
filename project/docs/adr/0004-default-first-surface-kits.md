# ADR 0004 — Default-first Surface Kits

## Context

KiNoTch.の初期構想では、CLI、Windows、MCP、APIなどの定型処理をRuntime中心に
共通化する案があった。一方、これらの処理はPortable Contractとして同じ実行意味を
持つとは限らず、既存FrameworkやProjectの責任を侵食しやすい。

## Decision

Domain意味を持たず、安全に外せ、Project単位でoverride / disableできる実装は、
L2 Surface / Tool Defaultとして提供する。Default-first方針の正本と判断規則は
[`.kinotch/meta/06_DEFAULT_FIRST_STANDARD.md`](../../../.kinotch/meta/06_DEFAULT_FIRST_STANDARD.md)
に置く。

v0.5.0ではCLI、Windows、MCP、API、AgentのSurface Kitと、ci-test、
generated-integrity、file-io、pwa、config、loggingのTool Defaultをこの境界で
扱う。

## Reason

Portable Contractの証明を待たずに反復実装を削減でき、既存FrameworkをOVERRIDEとして
保持できる。また、Surface helperをRuntimeへ押し込まず、Runtimeの肥大化と不要な
依存を避けられる。

## Consequences

- Surface KitはPortable Contractではない。
- Projectは`DEFAULT`、`OVERRIDE`、`DISABLED`を選択できる。
- DefaultはDomain format、公開API policy、永続状態、authority、deployを所有しない。
- Runtime昇格には、別途複数実装で意味・責任・変更理由を検証する。
- 既存実装をDefaultへ自動置換せず、必要なProject作業時に個別判断する。
