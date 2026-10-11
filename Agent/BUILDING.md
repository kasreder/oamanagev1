# OA Agent build configuration

The shared Agent module requires these build-only inputs for every Android,
Windows, or macOS compilation:

- `OA_AGENT_SUPABASE_URL`
- `OA_AGENT_SUPABASE_ANON_KEY`

Provide them through protected CI environment variables or an operator's
`~/.gradle/gradle.properties` (using the same property names). Do not put
them in this repository, `AgentConfig.kt`, an installer, or a checked-in
Gradle properties file. The anon key is public in a compiled client by design;
the purpose of this rule is to prevent stale deployment configuration and to
keep all privileged credentials out of clients.

For a local compile-only smoke test, supply a non-production HTTPS URL and a
synthetic three-part JWT whose decoded payload contains `"role":"anon"`.
It is accepted only as a configuration-shape fixture and must never be used to
produce a distributable package. Release builds must use the currently active
OA endpoint and anon key from the protected deployment secret store.

Example release invocation (values supplied by the CI secret store):

```sh
OA_AGENT_SUPABASE_URL="$OA_AGENT_SUPABASE_URL" \
OA_AGENT_SUPABASE_ANON_KEY="$OA_AGENT_SUPABASE_ANON_KEY" \
./gradlew :android:app:assembleRelease :windows:dist :macos:dist
```
