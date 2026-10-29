///|
/// Frozen generated-SVG inputs qualified by tests/raster-spike/evidence.json.
let still_fixtures : Array[(String, String)] = [
  ("sequence", still_source_0),
  ("zenuml", still_source_1),
  ("architecture", still_source_2),
  ("bpmn", still_source_3),
  ("swimlane", still_source_4),
  ("flowchart", still_source_5),
  ("regex", still_source_6),
  ("ebnf", still_source_7),
  ("json", still_source_8),
  ("yaml", still_source_9),
  ("state", still_source_10),
  ("adaptive-sequence", still_source_11),
  ("crossing-mask", still_source_12),
  ("icons-clip-mask", still_source_13),
]

///|
let still_source_0 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 371 288" width="371" height="288" role="img" data-diagram="sequence" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="seq-ce5d91653640fa60-diagram">
  #|  <title>Sequence diagram</title>
  #|  <desc>Sequence diagram with 2 participants (Alice, John) and 3 messages.</desc>
  #|  <defs>
  #|    <marker id="seq-ce5d91653640fa60-head-0-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#0891b2" stroke="#0891b2" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-ce5d91653640fa60-head-1-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#64748b" stroke="#64748b" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-ce5d91653640fa60-head-2-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0" fill="none" stroke="#0891b2" stroke-width="1.4"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="371" height="288" rx="0" fill="#f4f5f7"/>
  #|  <g class="bands"/>
  #|  <g class="lifelines">
  #|    <path class="lifeline" d="M80 72 V256" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M291 72 V256" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|  </g>
  #|  <g class="activations"/>
  #|  <g class="messages">
  #|    <g class="message f-frontend" data-index="0" data-from="Alice" data-to="John" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M87 127 L284 127" fill="none" stroke="#0891b2" stroke-width="1.4" marker-end="url(#seq-ce5d91653640fa60-head-0-end)" data-connector-id="0" data-connector-source="Alice" data-connector-target="John" data-connector-route="M87 127 L284 127" data-connector-key="0"/>
  #|      <rect class="mask" x="96" y="100" width="179" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="185" y="115" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#077995">
  #|        <tspan x="185" y="115">Hello John, how are you?</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-external" data-index="1" data-from="John" data-to="Alice" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M284 175 L87 175" fill="none" stroke="#64748b" stroke-width="1.4" stroke-dasharray="4 4" marker-end="url(#seq-ce5d91653640fa60-head-1-end)" data-connector-id="1" data-connector-source="John" data-connector-target="Alice" data-connector-route="M284 175 L87 175" data-connector-key="1"/>
  #|      <rect class="mask" x="157" y="148" width="57" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="185" y="163" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#606f85">
  #|        <tspan x="185" y="163">Great!</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-frontend" data-index="2" data-from="Alice" data-to="John" data-sender-head="none" data-receiver-head="async">
  #|      <path class="m-line" d="M87 223 L284 223" fill="none" stroke="#0891b2" stroke-width="1.4" marker-end="url(#seq-ce5d91653640fa60-head-2-end)" data-connector-id="2" data-connector-source="Alice" data-connector-target="John" data-connector-route="M87 223 L284 223" data-connector-key="2"/>
  #|      <rect class="mask" x="130" y="196" width="111" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="185" y="211" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#077995">
  #|        <tspan x="185" y="211">See you later!</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="notes"/>
  #|  <g class="participants">
  #|    <g class="participant f-frontend" data-id="Alice">
  #|      <rect class="mask" x="32" y="24" width="96" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="32" y="24" width="96" height="48" rx="6" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="p-label" x="80" y="52" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="80" y="52">Alice</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="participant f-backend" data-id="John">
  #|      <rect class="mask" x="243" y="24" width="96" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="243" y="24" width="96" height="48" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="p-label" x="291" y="52" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="291" y="52">John</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="annotations"/>
  #|</svg>

///|
let still_source_1 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1254 376" width="1254" height="376" role="img" data-diagram="sequence" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-diagram">
  #|  <title>Checkout interaction</title>
  #|  <desc>Sequence diagram with 7 participants (Customer, API, Worker, Functions, Analytics, Store, Cluster) and 4 messages.</desc>
  #|  <defs>
  #|    <symbol fill="none" viewBox="0 0 24 24" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-48">
  #|      <g>
  #|        <path d="M15.5489 4.19771C15.5489 5.18773 15.1485 6.13721 14.4358 6.83726C13.7231 7.53731 12.7565 7.93058 11.7486 7.93058C10.7407 7.93058 9.77403 7.53731 9.06133 6.83726C8.34863 6.13721 7.94824 5.18773 7.94824 4.19771C7.94824 3.20768 8.34863 2.25822 9.06133 1.55818C9.77403 0.858126 10.7407 0.464844 11.7486 0.464844C12.7565 0.464844 13.7231 0.858126 14.4358 1.55818C15.1485 2.25822 15.5489 3.20768 15.5489 4.19771Z" stroke="currentColor"/>
  #|        <path d="M6.54883 11.2152L17.2025 11.2073M11.7471 8.06641V19.5806V8.06641ZM11.7471 19.4385L6.79789 23.5738L11.7471 19.4385ZM11.7551 19.4385L17.1864 23.3055L11.7551 19.4385Z" stroke="currentColor"/>
  #|      </g>
  #|      <desc>Peng Xiao. MIT repository grant; provider icon terms: MIT. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/actor.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol viewBox="0 0 48 48" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-57">
  #|      <g fill="none" fill-rule="evenodd" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-57-i2" stroke="none" stroke-width="1">
  #|        <path d="M9,39 L39,39 L39,9 L9,9 L9,39 Z M46,13 L46,11 L41,11 L41,8 C41,7.448 40.552,7 40,7 L37,7 L37,2 L35,2 L35,7 L31,7 L31,2 L29,2 L29,7 L25,7 L25,2 L23,2 L23,7 L19,7 L19,2 L17,2 L17,7 L13,7 L13,2 L11,2 L11,7 L8,7 C7.447,7 7,7.448 7,8 L7,11 L2,11 L2,13 L7,13 L7,17 L2,17 L2,19 L7,19 L7,23 L2,23 L2,25 L7,25 L7,29 L2,29 L2,31 L7,31 L7,35 L2,35 L2,37 L7,37 L7,40 C7,40.553 7.447,41 8,41 L11,41 L11,46 L13,46 L13,41 L17,41 L17,46 L19,46 L19,41 L23,41 L23,46 L25,46 L25,41 L29,41 L29,46 L31,46 L31,41 L35,41 L35,46 L37,46 L37,41 L40,41 C40.552,41 41,40.553 41,40 L41,37 L46,37 L46,35 L41,35 L41,31 L46,31 L46,29 L41,29 L41,25 L46,25 L46,23 L41,23 L41,19 L46,19 L46,17 L41,17 L41,13 L46,13 Z" fill="#ED7100" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-57-i3"/>
  #|      </g>
  #|      <desc>Amazon Web Services. MIT repository grant; provider icon terms: https://aws.amazon.com/architecture/icons/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/AWS-Asset-Package_02062024/Resource-Icons_01312024/Res_Compute/Res_Amazon-EC2_Instance_48.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol viewBox="0 0 48 48" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-56">
  #|      <g fill="none" fill-rule="evenodd" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-56-i2" stroke="none" stroke-width="1">
  #|        <path d="M24,44 C12.972,44 4,35.028 4,24 C4,12.972 12.972,4 24,4 C35.028,4 44,12.972 44,24 C44,35.028 35.028,44 24,44 L24,44 Z M24,2 C11.869,2 2,11.869 2,24 C2,36.131 11.869,46 24,46 C36.131,46 46,36.131 46,24 C46,11.869 36.131,2 24,2 L24,2 Z M17.231,35.25 L11.876,35.25 L18.221,21.959 L20.902,27.492 L17.231,35.25 Z M19.114,19.215 C18.946,18.87 18.597,18.651 18.214,18.651 L18.211,18.651 C17.826,18.652 17.477,18.874 17.312,19.221 L9.389,35.819 C9.24,36.129 9.262,36.493 9.445,36.783 C9.628,37.074 9.947,37.25 10.291,37.25 L17.864,37.25 C18.251,37.25 18.603,37.027 18.769,36.678 L22.915,27.915 C23.044,27.642 23.043,27.323 22.911,27.051 L19.114,19.215 Z M36.125,35.25 L30.673,35.25 L20.761,13.953 C20.597,13.601 20.243,13.375 19.854,13.375 L16.251,13.375 L16.255,9.25 L23.475,9.25 L33.339,30.545 C33.503,30.898 33.856,31.125 34.246,31.125 L36.125,31.125 L36.125,35.25 Z M37.125,29.125 L34.885,29.125 L25.021,7.83 C24.856,7.477 24.503,7.25 24.113,7.25 L15.256,7.25 C14.704,7.25 14.257,7.697 14.256,8.249 L14.25,14.374 C14.25,14.64 14.355,14.894 14.543,15.082 C14.73,15.27 14.984,15.375 15.25,15.375 L19.217,15.375 L29.129,36.672 C29.293,37.024 29.646,37.25 30.035,37.25 L37.125,37.25 C37.678,37.25 38.125,36.803 38.125,36.25 L38.125,30.125 C38.125,29.572 37.678,29.125 37.125,29.125 L37.125,29.125 Z" fill="#ED7100" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-56-i3"/>
  #|      </g>
  #|      <desc>Amazon Web Services. MIT repository grant; provider icon terms: https://aws.amazon.com/architecture/icons/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/AWS-Asset-Package_02062024/Resource-Icons_01312024/Res_Compute/Res_AWS-Lambda_Lambda-Function_48.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol viewBox="0 0 18 18" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-50">
  #|      <defs>
  #|        <linearGradient gradientTransform="translate(212.573 370.548) scale(1.156 1.029)" gradientUnits="userSpaceOnUse" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-50-i2" x1="-175.993" x2="-175.993" y1="-343.723" y2="-359.232">
  #|          <stop offset="0" stop-color="#fea11b"/>
  #|          <stop offset="0.284" stop-color="#fea51a"/>
  #|          <stop offset="0.547" stop-color="#feb018"/>
  #|          <stop offset="0.8" stop-color="#ffc314"/>
  #|          <stop offset="1" stop-color="#ffd70f"/>
  #|        </linearGradient>
  #|      </defs>
  #|      <g>
  #|        <path d="M2.37,7.475H3.2a.267.267,0,0,1,.267.267v6.148a.533.533,0,0,1-.533.533H2.1a0,0,0,0,1,0,0V7.741a.267.267,0,0,1,.267-.267Z" fill="#50e6ff" transform="translate(12.507 16.705) rotate(134.919)"/>
  #|        <path d="M2.325,3.6h.833a.267.267,0,0,1,.267.267v6.583a0,0,0,0,1,0,0H2.591a.533.533,0,0,1-.533-.533V3.865A.267.267,0,0,1,2.325,3.6Z" fill="#1490df" transform="translate(5.759 0.114) rotate(44.919)"/>
  #|      </g>
  #|      <g>
  #|        <path d="M14.53,7.475h.833a.533.533,0,0,1,.533.533v6.148a.267.267,0,0,1-.267.267H14.8a.267.267,0,0,1-.267-.267V7.475a0,0,0,0,1,0,0Z" fill="#50e6ff" transform="translate(12.223 -7.555) rotate(45.081)"/>
  #|        <path d="M15.108,3.6h.833a0,0,0,0,1,0,0v6.583a.267.267,0,0,1-.267.267h-.833a.267.267,0,0,1-.267-.267V4.131a.533.533,0,0,1,.533-.533Z" fill="#1490df" transform="translate(31.022 1.222) rotate(135.081)"/>
  #|      </g>
  #|      <path d="M8.459,9.9H4.87a.193.193,0,0,1-.2-.181.166.166,0,0,1,.018-.075L8.991,1.13a.206.206,0,0,1,.186-.106h4.245a.193.193,0,0,1,.2.181.165.165,0,0,1-.035.1L8.534,7.966h4.928a.193.193,0,0,1,.2.181.176.176,0,0,1-.052.122L5.421,16.788c-.077.046-.624.5-.356-.189h0Z" fill="url(#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-50-i2)"/>
  #|      <desc>Microsoft. MIT repository grant; provider icon terms: https://learn.microsoft.com/en-us/azure/architecture/icons/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/Azure_Public_Service_Icons/Icons/Compute/10029-icon-service-Function-Apps.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol viewBox="0 0 24 24" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-56">
  #|      <defs/>
  #|      <g>
  #|        <g>
  #|          <path d="M6.73,10.83v2.63A4.91,4.91,0,0,0,8.44,15.2V10.83Z" fill="#aecbfa" fill-rule="evenodd"/>
  #|          <path d="M9.89,8.41v7.53A7.62,7.62,0,0,0,11,16,8,8,0,0,0,12,16V8.41Z" fill="#669df6" fill-rule="evenodd"/>
  #|          <path d="M13.64,11.86v3.29a5,5,0,0,0,1.7-1.82V11.86Z" fill="#aecbfa" fill-rule="evenodd"/>
  #|          <path d="M17.74,16.32l-1.42,1.42a.42.42,0,0,0,0,.6l3.54,3.54a.42.42,0,0,0,.59,0l1.43-1.43a.42.42,0,0,0,0-.59l-3.54-3.54a.42.42,0,0,0-.6,0" fill="#4285f4" fill-rule="evenodd"/>
  #|          <path d="M11,2a9,9,0,1,0,9,9,9,9,0,0,0-9-9m0,15.69A6.68,6.68,0,1,1,17.69,11,6.68,6.68,0,0,1,11,17.69" fill="#669df6" fill-rule="evenodd"/>
  #|        </g>
  #|      </g>
  #|      <desc>Google. MIT repository grant; provider icon terms: https://cloud.google.com/icons. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/google-cloud-icons/bigquery/bigquery.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol fill="#000000" viewBox="0 0 32 32" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-52-49">
  #|      <path d="M24.295 9.929c-0.010 0.155-0.082 0.292-0.191 0.387l-0.001 0.001c-0.131 0.143-0.306 0.243-0.504 0.278l-0.005 0.001c-0.028 0.004-0.061 0.007-0.094 0.007h-0c-0.001 0-0.003 0-0.004 0-0.312 0-0.58-0.189-0.694-0.46l-0.002-0.005c-0.030-0.221 0.33-0.388 0.701-0.44s0.764 0.011 0.794 0.231zM14.385 10.443c-0.121 0.311-0.418 0.528-0.766 0.528-0.004 0-0.007-0-0.011-0h0.001c-0 0-0 0-0 0-0.036 0-0.070-0.003-0.105-0.007l0.004 0c-0.261-0.047-0.483-0.191-0.63-0.392l-0.002-0.003c-0.082-0.094-0.132-0.219-0.132-0.354 0-0 0-0.001 0-0.001v0c0.012-0.077 0.055-0.143 0.115-0.185l0.001-0.001c0.152-0.084 0.334-0.133 0.528-0.133 0.083 0 0.164 0.009 0.242 0.026l-0.007-0.001c0.395 0.055 0.803 0.242 0.764 0.523zM25.403 18.086l-0.107-0.134-0.044-0.055c0.457-0.846 0.725-1.853 0.725-2.921 0-0.488-0.056-0.962-0.162-1.418l0.008 0.042c-0.070-0.453-0.111-0.976-0.111-1.508 0-0.007 0-0.014 0-0.021v0.001c0.023-0.501 0.076-0.97 0.158-1.429l-0.010 0.066c0.089-0.464 0.14-0.998 0.14-1.544 0-0.051-0-0.101-0.001-0.151l0 0.008c0.012-0.049 0.019-0.104 0.019-0.162 0-0.027-0.002-0.053-0.004-0.079l0 0.003c-0.4-1.58-1.151-2.949-2.168-4.073l0.007 0.008c-0.911-1.068-2.031-1.929-3.3-2.523l-0.060-0.025c0.696-0.149 1.496-0.234 2.316-0.234 0.075 0 0.15 0.001 0.225 0.002l-0.011-0c0.045-0.001 0.097-0.002 0.15-0.002 2.378 0 4.496 1.109 5.866 2.838l0.012 0.016c0.028 0.036 0.056 0.077 0.080 0.12l0.003 0.005c0.904 1.694-0.345 7.842-3.732 13.172zM25.117 9.322c-0.016 0.455-0.064 0.886-0.14 1.307l0.008-0.055c-0.078 0.425-0.134 0.931-0.157 1.445l-0.001 0.025c-0 0.017-0 0.036-0 0.056 0 0.567 0.042 1.124 0.124 1.668l-0.008-0.061c0.085 0.377 0.134 0.809 0.134 1.254 0 0.763-0.144 1.493-0.407 2.162l0.014-0.040c-0.076-0.131-0.155-0.289-0.224-0.453l-0.011-0.029c-0.066-0.159-0.209-0.416-0.406-0.77-0.769-1.38-2.571-4.611-1.649-5.929 0.474-0.678 1.676-0.707 2.722-0.579zM24.406 20.907c-0.051-1.039 0.336-1.148 0.746-1.263q0.085-0.023 0.169-0.051c0.050 0.044 0.105 0.087 0.162 0.125l0.005 0.003c0.62 0.273 1.342 0.431 2.102 0.431 0.592 0 1.161-0.096 1.693-0.274l-0.038 0.011c-0.344 0.293-0.736 0.544-1.16 0.738l-0.031 0.013c-0.644 0.264-1.391 0.429-2.173 0.454l-0.010 0c-0.119 0.018-0.256 0.029-0.395 0.029-0.386 0-0.754-0.080-1.087-0.224l0.018 0.007zM23.293 22.933c-0.021 0.221-0.045 0.47-0.077 0.745l-0.182 0.548c-0.014 0.040-0.022 0.086-0.023 0.134v0c0.001 0.027 0.001 0.058 0.001 0.089 0 0.355-0.053 0.699-0.151 1.022l0.006-0.025c-0.116 0.389-0.196 0.84-0.223 1.305l-0.001 0.016c-0.052 1.684-1.355 3.047-3.008 3.194l-0.013 0.001c-1.894 0.406-2.23-0.621-2.526-1.527q-0.045-0.142-0.096-0.283c-0.16-0.652-0.252-1.401-0.252-2.171 0-0.36 0.020-0.715 0.059-1.065l-0.004 0.043c0.006-0.128 0.009-0.279 0.009-0.43 0-1.026-0.154-2.016-0.441-2.948l0.019 0.071q0.008-0.55 0.024-1.114c0-0.003 0-0.008 0-0.012 0-0.046-0.007-0.090-0.020-0.132l0.001 0.003c-0.014-0.1-0.033-0.188-0.058-0.273l0.003 0.013c-0.141-0.521-0.496-0.941-0.964-1.164l-0.011-0.005c-0.176-0.088-0.384-0.14-0.605-0.14-0.104 0-0.205 0.011-0.302 0.033l0.009-0.002c0.128-0.47 0.26-0.854 0.412-1.228l-0.026 0.073 0.066-0.177c0.074-0.2 0.167-0.407 0.266-0.626 0.546-1.124 0.865-2.445 0.865-3.841 0-0.938-0.144-1.842-0.411-2.692l0.017 0.063c-0.183-1.108-1.135-1.943-2.281-1.943-0.18 0-0.356 0.021-0.524 0.060l0.016-0.003c-0.796 0.104-1.516 0.338-2.171 0.682l0.035-0.017q-0.124 0.063-0.245 0.13c0.091-2.147 0.896-4.090 2.181-5.615l-0.012 0.014c0.118-0.119 0.242-0.232 0.37-0.338l0.009-0.007c0.069-0.014 0.13-0.042 0.182-0.081l-0.001 0.001c0.893-0.654 2.014-1.047 3.227-1.047 0.097 0 0.193 0.002 0.288 0.007l-0.013-0.001c0.526 0.008 1.034 0.044 1.534 0.108l-0.067-0.007c2.043 0.393 3.787 1.463 5.032 2.963l0.011 0.014c0.748 0.869 1.354 1.887 1.766 2.998l0.022 0.069c-0.257-0.069-0.552-0.109-0.856-0.109-0.983 0-1.868 0.416-2.49 1.081l-0.002 0.002c-1.24 1.773 0.679 5.215 1.601 6.869 0.169 0.303 0.315 0.565 0.361 0.676 0.26 0.601 0.587 1.118 0.98 1.577l-0.007-0.008c0.087 0.109 0.171 0.214 0.236 0.306-0.501 0.144-1.401 0.478-1.319 2.146-0.015 0.195-0.053 0.558-0.104 1.018-0.054 0.269-0.098 0.597-0.123 0.93l-0.002 0.028zM14.091 17.219l-0.066 0.176c-0.137 0.328-0.279 0.745-0.397 1.172l-0.019 0.081c-0.893-0.013-1.695-0.395-2.261-1.001l-0.002-0.002c-0.632-0.667-1.020-1.57-1.020-2.564 0-0.198 0.015-0.392 0.045-0.582l-0.003 0.021c0.097-0.72 0.153-1.551 0.153-2.396 0-0.502-0.020-0.999-0.058-1.491l0.004 0.065c-0.006-0.107-0.012-0.201-0.015-0.275 0.805-0.611 1.824-0.98 2.929-0.98 0.132 0 0.262 0.005 0.391 0.015l-0.017-0.001c0.554 0.129 0.971 0.588 1.037 1.153l0.001 0.006c0.238 0.728 0.375 1.566 0.375 2.435 0 1.266-0.291 2.464-0.809 3.532l0.021-0.048c-0.105 0.233-0.204 0.453-0.289 0.682zM11.474 22.203c-0.205-0.052-0.385-0.128-0.549-0.227l0.009 0.005c0.172-0.073 0.375-0.134 0.585-0.173l0.019-0.003c1.604-0.33 1.851-0.563 2.392-1.25 0.124-0.157 0.264-0.336 0.459-0.553 0.040-0.045 0.072-0.099 0.091-0.159l0.001-0.003c0.213-0.189 0.34-0.137 0.546-0.052 0.227 0.125 0.395 0.336 0.46 0.587l0.001 0.007c0.023 0.065 0.037 0.139 0.037 0.217 0 0.125-0.035 0.242-0.095 0.341l0.002-0.003c-0.645 0.882-1.676 1.449-2.839 1.449-0.4 0-0.785-0.067-1.144-0.191l0.025 0.007zM3.967 15.846c-0.651-1.985-1.181-4.34-1.494-6.764l-0.021-0.199c-0.061-0.322-0.095-0.693-0.095-1.071 0-1.806 0.789-3.427 2.041-4.537l0.006-0.005c2.295-1.623 6.048-0.676 7.633-0.163l-0.012 0.012c-1.535 1.872-2.466 4.292-2.466 6.928 0 0.090 0.001 0.18 0.003 0.27l-0-0.013c-0 0.103 0.008 0.249 0.020 0.449 0.033 0.41 0.052 0.888 0.052 1.371 0 0.802-0.052 1.592-0.154 2.367l0.010-0.091c-0.033 0.206-0.051 0.444-0.051 0.686 0 1.231 0.482 2.35 1.269 3.177l-0.002-0.002q0.151 0.158 0.315 0.297c-0.433 0.464-1.375 1.49-2.377 2.696-0.709 0.853-1.199 0.689-1.36 0.636-0.685-0.368-1.222-0.939-1.538-1.631l-0.009-0.022c-0.684-1.252-1.286-2.708-1.73-4.232l-0.039-0.157zM30.445 19.403c-0.019-0.057-0.043-0.106-0.072-0.151l0.002 0.003c-0.174-0.329-0.596-0.427-1.259-0.29-2.066 0.426-2.866 0.164-3.156-0.024 1.617-2.452 2.918-5.292 3.751-8.326l0.049-0.209c0.339-1.313 0.997-4.403 0.153-5.913-0.059-0.112-0.122-0.208-0.192-0.298l0.003 0.004c-1.563-1.955-3.948-3.196-6.623-3.196-0.076 0-0.152 0.001-0.227 0.003l0.011-0c-0.042-0.001-0.091-0.001-0.141-0.001-1.342 0-2.633 0.22-3.838 0.625l0.085-0.025q-0.321-0.060-0.645-0.102c-0.488-0.093-1.053-0.151-1.631-0.16l-0.008-0c-0.083-0.004-0.18-0.006-0.278-0.006-1.315 0-2.538 0.394-3.557 1.071l0.024-0.015c-1.071-0.401-5.984-2.056-9.025 0.098-1.489 1.27-2.426 3.147-2.426 5.244 0 0.405 0.035 0.802 0.102 1.188l-0.006-0.041c0.335 2.698 0.879 5.126 1.632 7.461l-0.079-0.284c0.493 1.716 1.103 3.201 1.852 4.6l-0.061-0.124c0.433 0.984 1.182 1.764 2.116 2.225l0.026 0.012c0.168 0.049 0.361 0.078 0.561 0.078 0.742 0 1.392-0.391 1.756-0.979l0.005-0.009c1.001-1.204 1.987-2.282 2.43-2.758 0.502 0.279 1.097 0.451 1.731 0.471l0.006 0 0.001 0.005q-0.158 0.188-0.309 0.382c-0.424 0.538-0.512 0.649-1.875 0.93-0.388 0.080-1.418 0.292-1.433 1.014-0 0.004-0 0.008-0 0.013 0 0.147 0.043 0.284 0.117 0.399l-0.002-0.003c0.312 0.395 0.751 0.678 1.254 0.788l0.015 0.003c0.399 0.13 0.859 0.205 1.335 0.205 1.1 0 2.106-0.398 2.884-1.058l-0.006 0.005c-0.024 0.418-0.037 0.908-0.037 1.401 0 1.753 0.171 3.467 0.496 5.125l-0.027-0.167c0.382 1.373 1.616 2.367 3.084 2.38h0.002c0.369-0.003 0.726-0.046 1.070-0.124l-0.033 0.006c1.919-0.171 3.431-1.705 3.567-3.619l0.001-0.012c0.188-1.088 0.502-3.593 0.673-5.125 0.008-0.065 0.034-0.123 0.072-0.171l-0.001 0.001c0.001-0.001 0.087-0.059 0.534 0.038l0.055 0.009 0.317 0.028 0.019 0.001c0.095 0.004 0.207 0.007 0.319 0.007 1.024 0 2.002-0.2 2.895-0.564l-0.051 0.018c0.805-0.373 2.256-1.29 1.993-2.087z"/>
  #|      <desc>Respective technology owners; SVG Repo contributors. MIT repository grant; provider icon terms: https://www.svgrepo.com/page/licensing/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/HLD-Architecture/postgresql.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <symbol fill="none" viewBox="0 0 16 16" id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-52-51">
  #|      <path clip-rule="evenodd" d="M5.374 15c-.335 0-.66-.153-.874-.431l-3.254-4.172a1.15 1.15 0 01-.214-.978l1.165-5.207c.074-.345.298-.623.605-.776l4.715-2.32c.15-.078.317-.116.485-.116.168 0 .335.038.485.115L13.2 3.426c.308.153.532.432.606.777l1.165 5.207c.074.345 0 .7-.214.978L11.5 14.566c-.214.268-.54.434-.875.434h-5.25zm7.718-5.835l.031.008a.308.308 0 01.26.371.306.306 0 01-.396.223h-.004l-.003-.001-.003-.001-.03-.007-.05-.01a2.548 2.548 0 01-.274-.106 2.87 2.87 0 00-.533-.156.242.242 0 00-.171.063 4.76 4.76 0 00-.131-.023 3.972 3.972 0 01-1.764 2.212c.015.042.032.083.051.123a.239.239 0 00-.023.18c.074.17.165.332.271.484.06.078.114.16.164.244l.028.057.012.025a.306.306 0 01-.381.44.307.307 0 01-.172-.18 2.608 2.608 0 00-.01-.02l-.028-.058a2.545 2.545 0 01-.089-.28 2.835 2.835 0 00-.21-.512.242.242 0 00-.156-.095 5.926 5.926 0 01-.03-.053l-.035-.064a3.97 3.97 0 01-2.824-.007l-.069.125a.249.249 0 00-.132.064c-.104.17-.184.355-.237.548a2.525 2.525 0 01-.088.28l-.025.05-.013.027v.001a.307.307 0 11-.553-.261l.014-.03.026-.052c.05-.085.104-.166.164-.244.108-.156.2-.322.277-.496a.302.302 0 00-.028-.173l.056-.133A3.972 3.972 0 014.22 9.532l-.134.023a.34.34 0 00-.176-.062 2.872 2.872 0 00-.533.156c-.09.04-.181.075-.274.105l-.05.011-.03.007H3.02l-.002.002h-.005a.308.308 0 01-.397-.349.306.306 0 01.261-.245l.004-.001h.003l.006-.002c.024-.006.054-.014.076-.018.097-.013.195-.021.293-.023.186-.013.37-.043.549-.09a.422.422 0 00.131-.133l.128-.037a3.938 3.938 0 01.624-2.752l-.097-.087a.338.338 0 00-.062-.176 2.854 2.854 0 00-.455-.319 2.557 2.557 0 01-.254-.148 1.129 1.129 0 01-.063-.05l-.004-.004a.323.323 0 01-.076-.45.295.295 0 01.244-.107.365.365 0 01.213.08l.022.017c.016.013.034.026.046.037.071.067.139.139.202.213.125.137.263.262.412.372.056.03.121.036.182.018l.11.078a3.938 3.938 0 012.552-1.224l.007-.129a.332.332 0 00.1-.157 2.844 2.844 0 00-.034-.554 2.555 2.555 0 01-.042-.29v-.053-.025-.004-.004A.306.306 0 018 2.82a.308.308 0 01.306.337v.087a2.53 2.53 0 01-.041.29 2.85 2.85 0 00-.035.553.242.242 0 00.1.153v.007l.007.13c.967.087 1.87.522 2.54 1.223l.116-.083a.34.34 0 00.186-.02c.149-.11.287-.235.412-.373a2.53 2.53 0 01.202-.213l.051-.04.017-.014a.308.308 0 01.472.388.307.307 0 01-.09.09c-.008.005-.017.012-.025.02l-.043.033a2.549 2.549 0 01-.254.148 2.865 2.865 0 00-.455.32.24.24 0 00-.058.172 4.458 4.458 0 01-.05.044l-.058.053c.542.806.769 1.783.637 2.745l.123.036c.031.056.077.101.132.132.18.048.364.078.55.09.097.003.195.01.292.024l.058.013zm-2.875-3.1l-1.308.925-.004-.002a.27.27 0 01-.43-.205v-.001l-.091-1.598a3.183 3.183 0 011.833.882zM7.754 7.818h.492l.306.381-.11.476L8 8.886l-.443-.213-.11-.475.307-.381zM7.29 5.24c.107-.024.216-.043.326-.056l-.09 1.6-.008.004a.268.268 0 01-.293.256.27.27 0 01-.135-.05l-.002.001-1.316-.93c.419-.41.945-.696 1.518-.825zM5.296 6.663l1.201 1.071-.001.007a.269.269 0 01-.106.462l-.001.005-1.54.443a3.134 3.134 0 01.447-1.988zm1.608 2.846l-.612 1.474a3.16 3.16 0 01-1.27-1.586L6.6 9.13l.003.003a.265.265 0 01.18.029.27.27 0 01.117.341l.004.006zm1.806 1.896c-.572.13-1.17.1-1.726-.088l.777-1.4h.001a.27.27 0 01.475-.001h.006l.779 1.402a3.286 3.286 0 01-.312.087zm1.004-.416L9.096 9.5l.001-.003a.269.269 0 01.296-.37l.003-.004 1.593.269a3.147 3.147 0 01-1.275 1.597zm1.442-2.343L9.61 8.201l-.002-.006a.27.27 0 01-.185-.343.27.27 0 01.08-.12L9.5 7.73l1.195-1.067c.366.594.527 1.29.46 1.983z" fill="#000000" fill-rule="evenodd"/>
  #|      <desc>Respective technology owners; SVG Repo contributors. MIT repository grant; provider icon terms: https://www.svgrepo.com/page/licensing/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/HLD-Architecture/kubernetes.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol>
  #|    <marker id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-0-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#0891b2" stroke="#0891b2" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-1-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#0891b2" stroke="#0891b2" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-2-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0" fill="none" stroke="#ea580c" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-3-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0" fill="none" stroke="#7c3aed" stroke-width="1.4"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="1254" height="376" rx="0" fill="#f4f5f7"/>
  #|  <g class="bands"/>
  #|  <g class="lifelines">
  #|    <path class="lifeline" d="M98 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M285 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M464 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M639 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M825 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M996 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M1160 112 V344" fill="none" stroke="#64748b" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|  </g>
  #|  <g class="activations">
  #|    <rect class="activation-mask" x="459" y="215" width="10" height="48" rx="0" fill="#ffffff"/>
  #|    <rect class="activation" x="459" y="215" width="10" height="48" rx="0" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|    <rect class="activation-mask" x="280" y="167" width="10" height="144" rx="0" fill="#ffffff"/>
  #|    <rect class="activation" x="280" y="167" width="10" height="144" rx="0" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|  </g>
  #|  <g class="messages">
  #|    <g class="message f-frontend" data-index="0" data-from="Customer" data-to="API" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M105 167 L278 167" fill="none" stroke="#0891b2" stroke-width="1.4" marker-end="url(#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-0-end)" data-connector-id="0" data-connector-source="Customer" data-connector-target="API" data-connector-route="M105 167 L278 167" data-connector-key="0"/>
  #|      <rect class="mask" x="149" y="140" width="84" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="191" y="155" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#077995">
  #|        <tspan x="191" y="155">checkout()</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-frontend" data-index="1" data-from="API" data-to="Worker" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M290 215 L457 215" fill="none" stroke="#0891b2" stroke-width="1.4" marker-end="url(#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-1-end)" data-connector-id="1" data-connector-source="API" data-connector-target="Worker" data-connector-route="M290 215 L457 215" data-connector-key="1"/>
  #|      <rect class="mask" x="336" y="188" width="77" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="374" y="203" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#077995">
  #|        <tspan x="374" y="203">process()</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-messagebus" data-index="2" data-from="Store" data-to="Analytics" data-sender-head="none" data-receiver-head="async">
  #|      <path class="m-line" d="M989 263 L832 263" fill="none" stroke="#ea580c" stroke-width="1.4" marker-end="url(#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-2-end)" data-connector-id="2" data-connector-source="Store" data-connector-target="Analytics" data-connector-route="M989 263 L832 263" data-connector-key="2"/>
  #|      <rect class="mask" x="882" y="236" width="57" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="910" y="251" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#c3490a">
  #|        <tspan x="910" y="251">record</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-database" data-index="3" data-from="Functions" data-to="Cluster" data-sender-head="none" data-receiver-head="async">
  #|      <path class="m-line" d="M646 311 L1153 311" fill="none" stroke="#7c3aed" stroke-width="1.4" marker-end="url(#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74-head-3-end)" data-connector-id="3" data-connector-source="Functions" data-connector-target="Cluster" data-connector-route="M646 311 L1153 311" data-connector-key="3"/>
  #|      <rect class="mask" x="844" y="284" width="111" height="23" rx="3" fill="#ffffff"/>
  #|      <text class="m-label" x="899" y="299" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#7c3aed">
  #|        <tspan x="899" y="299">deploy request</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="notes"/>
  #|  <g class="participants">
  #|    <g class="participant f-frontend" data-id="Customer">
  #|      <rect class="mask" x="32" y="64" width="132" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="32" y="64" width="132" height="48" rx="6" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="p-label" x="118" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="118" y="92">Customer</tspan>
  #|      </text>
  #|      <rect x="44" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:actor" color="#111827">
  #|        <title>zenuml:actor</title>
  #|        <rect x="44" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-48" x="44" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-frontend" data-id="API">
  #|      <rect class="mask" x="212" y="64" width="146" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="212" y="64" width="146" height="48" rx="6" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="p-label" x="305" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="305" y="92">Orders API</tspan>
  #|      </text>
  #|      <rect x="224" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:ec2" color="#111827">
  #|        <title>zenuml:ec2</title>
  #|        <rect x="224" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-57" x="224" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-backend" data-id="Worker">
  #|      <rect class="mask" x="406" y="64" width="117" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="406" y="64" width="117" height="48" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="p-label" x="484" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="484" y="92">Worker</tspan>
  #|      </text>
  #|      <rect x="418" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:lambda" color="#111827">
  #|        <title>zenuml:lambda</title>
  #|        <rect x="418" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-50-57-56" x="418" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-database" data-id="Functions">
  #|      <rect class="mask" x="570" y="64" width="139" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="570" y="64" width="139" height="48" rx="6" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="p-label" x="659" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="659" y="92">Functions</tspan>
  #|      </text>
  #|      <rect x="582" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:azurefunction" color="#111827">
  #|        <title>zenuml:azurefunction</title>
  #|        <rect x="582" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-50" x="582" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-cloud" data-id="Analytics">
  #|      <rect class="mask" x="756" y="64" width="139" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="756" y="64" width="139" height="48" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="p-label" x="845" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="845" y="92">Analytics</tspan>
  #|      </text>
  #|      <rect x="768" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:bigquery" color="#111827">
  #|        <title>zenuml:bigquery</title>
  #|        <rect x="768" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-56" x="768" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-messagebus" data-id="Store">
  #|      <rect class="mask" x="942" y="64" width="109" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="942" y="64" width="109" height="48" rx="6" fill="rgba(251, 146, 60, 0.15)" stroke="#ea580c" stroke-width="1.5"/>
  #|      <text class="p-label" x="1016" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="1016" y="92">Store</tspan>
  #|      </text>
  #|      <rect x="954" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:postgresql" color="#111827">
  #|        <title>zenuml:postgresql</title>
  #|        <rect x="954" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-52-49" x="954" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|    <g class="participant f-frontend" data-id="Cluster">
  #|      <rect class="mask" x="1098" y="64" width="124" height="48" rx="6" fill="#ffffff"/>
  #|      <rect class="box" x="1098" y="64" width="124" height="48" rx="6" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="p-label" x="1180" y="92" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|        <tspan x="1180" y="92">Cluster</tspan>
  #|      </text>
  #|      <rect x="1110" y="72" width="32" height="32" rx="4" fill="#ffffff"/>
  #|      <g role="img" aria-label="zenuml:kubernetes" color="#111827">
  #|        <title>zenuml:kubernetes</title>
  #|        <rect x="1110" y="72" width="32" height="32" rx="2" fill="#ffffff"/>
  #|        <use href="#seq-u-7a-65-6e-75-6d-6c-2d-73-79-6d-62-6f-6c-73-2d-6c-69-67-68-74--icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-52-51" x="1110" y="72" width="32" height="32"/>
  #|      </g>
  #|    </g>
  #|  </g>
  #|  <g class="annotations">
  #|    <rect class="mask" x="32" y="16" width="1190" height="32" rx="3" fill="#ffffff"/>
  #|    <text class="diagram-title" x="627" y="36" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="#111827">
  #|      <tspan x="627" y="36">Checkout interaction</tspan>
  #|    </text>
  #|  </g>
  #|</svg>

///|
let still_source_2 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-diagram" viewBox="0 0 2196 596" width="2196" height="596" role="img" data-diagram="architecture" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}">
  #|  <title>Order processing</title>
  #|  <desc>Authored connections, not deployment execution</desc>
  #|  <defs>
  #|    <symbol viewBox="0 0 32 32" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-99-108-111-117-100">
  #|      <path d="M8 24C0 24 0 12 8 12C10 1 25 1 27 12C35 12 35 24 27 24Z" fill="#e8f0fe" stroke="#234b75" stroke-width="1.5"/>
  #|    </symbol>
  #|    <symbol viewBox="0 0 32 32" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-115-101-114-118-101-114">
  #|      <path d="M4 3H28V11H4ZM4 13H28V21H4ZM4 23H28V31H4ZM8 7H10M8 17H10M8 27H10" fill="#e8f0fe" stroke="#234b75" stroke-width="1.5"/>
  #|    </symbol>
  #|    <symbol viewBox="0 0 32 32" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-100-97-116-97-98-97-115-101">
  #|      <path d="M4 7C4 1 28 1 28 7V25C28 31 4 31 4 25ZM4 7C4 13 28 13 28 7M4 16C4 22 28 22 28 16" fill="#e8f0fe" stroke="#234b75" stroke-width="1.5"/>
  #|    </symbol>
  #|    <symbol viewBox="0 0 32 32" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-100-105-115-107">
  #|      <path d="M3 3H26L29 6V29H3ZM8 3V12H24V3M8 29V18H24V29" fill="#e8f0fe" stroke="#234b75" stroke-width="1.5"/>
  #|    </symbol>
  #|    <symbol viewBox="0 0 32 32" id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-105-110-116-101-114-110-101-116">
  #|      <path d="M2 16A14 14 0 1 0 30 16A14 14 0 1 0 2 16M2 16H30M16 2C6 9 6 23 16 30C26 23 26 9 16 2M5 8H27M5 24H27" fill="#e8f0fe" stroke="#234b75" stroke-width="1.5"/>
  #|    </symbol>
  #|    <marker id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-0-start" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#64748b" stroke="#64748b" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-0-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#64748b" stroke="#64748b" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-1-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#64748b" stroke="#64748b" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-3-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="#64748b" stroke="#64748b" stroke-width="1.4"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="2196" height="596" fill="#f4f5f7"/>
  #|  <g class="architecture-groups">
  #|    <g class="architecture-group" data-id="cloud">
  #|      <rect class="architecture-group" x="56" y="56" width="1150" height="460" rx="6" fill="rgba(148, 163, 184, 0.18)" stroke="#64748b" stroke-width="1.5"/>
  #|      <text class="group-label" x="631" y="79" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="631" y="79">Cloud</tspan>
  #|      </text>
  #|      <g role="img" aria-label="architecture:cloud" color="#111827">
  #|        <title>architecture:cloud</title>
  #|        <rect x="64" y="64" width="24" height="24" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-99-108-111-117-100" x="64" y="64" width="24" height="24"/>
  #|      </g>
  #|    </g>
  #|    <g class="architecture-group" data-id="backend">
  #|      <rect class="architecture-group" x="112" y="176" width="232" height="284" rx="6" fill="rgba(148, 163, 184, 0.18)" stroke="#64748b" stroke-width="1.5"/>
  #|      <text class="group-label" x="228" y="199" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="228" y="199">Backend</tspan>
  #|      </text>
  #|      <g role="img" aria-label="architecture:server" color="#111827">
  #|        <title>architecture:server</title>
  #|        <rect x="120" y="184" width="24" height="24" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-115-101-114-118-101-114" x="120" y="184" width="24" height="24"/>
  #|      </g>
  #|    </g>
  #|  </g>
  #|  <g class="architecture-connections">
  #|    <g class="architecture-connection" data-id="edge-0" data-from="api" data-to="db">
  #|      <path class="architecture-path" d="M288 350 L320 350 L593 350 L625 350" fill="none" stroke="#64748b" stroke-width="1.5" marker-start="url(#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-0-start)" marker-end="url(#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-0-end)" data-connector-id="edge-0" data-connector-source="api" data-connector-target="db" data-connector-route="M288 350 L320 350 L593 350 L625 350" data-connector-key="0"/>
  #|    </g>
  #|    <g class="architecture-connection" data-id="edge-1" data-from="db" data-to="hub">
  #|      <path class="architecture-path" d="M685 404 L685 436 L913 436 L913 310 L1142 310 L1142 342" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-1-end)" data-connector-id="edge-1" data-connector-source="db" data-connector-target="hub" data-connector-route="M685 404 L685 436 L913 436 L913 310 L1142 310 L1142 342" data-connector-key="1"/>
  #|    </g>
  #|    <g class="architecture-connection" data-id="edge-2" data-from="hub" data-to="disk">
  #|      <path class="architecture-path" d="M1150 350 L1182 350 L1507 350 L1539 350" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="edge-2" data-connector-source="hub" data-connector-target="disk" data-connector-route="M1150 350 L1182 350 L1507 350 L1539 350" data-connector-key="2"/>
  #|    </g>
  #|    <g class="architecture-connection" data-id="edge-3" data-from="disk" data-to="net">
  #|      <path class="architecture-path" d="M1659 350 L1691 350 L1964 350 L1996 350" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74-head-3-end)" data-connector-id="edge-3" data-connector-source="disk" data-connector-target="net" data-connector-route="M1659 350 L1691 350 L1964 350 L1996 350" data-connector-key="3"/>
  #|    </g>
  #|  </g>
  #|  <g class="architecture-nodes">
  #|    <g class="architecture-service" data-id="api">
  #|      <rect class="service-box" x="168" y="296" width="120" height="108" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <g role="img" aria-label="architecture:server" color="#111827">
  #|        <title>architecture:server</title>
  #|        <rect x="208" y="308" width="40" height="40" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-115-101-114-118-101-114" x="208" y="308" width="40" height="40"/>
  #|      </g>
  #|      <text class="service-label" x="228" y="382" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="228" y="382">API</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="architecture-service" data-id="db">
  #|      <rect class="service-box" x="625" y="296" width="120" height="108" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <g role="img" aria-label="architecture:database" color="#111827">
  #|        <title>architecture:database</title>
  #|        <rect x="665" y="308" width="40" height="40" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-100-97-116-97-98-97-115-101" x="665" y="308" width="40" height="40"/>
  #|      </g>
  #|      <text class="service-label" x="685" y="382" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="685" y="382">Database</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="architecture-service" data-id="disk">
  #|      <rect class="service-box" x="1539" y="296" width="120" height="108" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <g role="img" aria-label="architecture:disk" color="#111827">
  #|        <title>architecture:disk</title>
  #|        <rect x="1579" y="308" width="40" height="40" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-100-105-115-107" x="1579" y="308" width="40" height="40"/>
  #|      </g>
  #|      <text class="service-label" x="1599" y="382" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="1599" y="382">Disk</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="architecture-service" data-id="net">
  #|      <rect class="service-box" x="1996" y="296" width="120" height="108" rx="6" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <g role="img" aria-label="architecture:internet" color="#111827">
  #|        <title>architecture:internet</title>
  #|        <rect x="2036" y="308" width="40" height="40" rx="2" fill="#ffffff"/>
  #|        <use href="#arch-u-61-72-63-68-69-74-65-63-74-75-72-65-2d-63-6c-6f-75-64-2d-6c-69-67-68-74--icon-p-97-114-99-104-105-116-101-99-116-117-114-101-p-105-110-116-101-114-110-101-116" x="2036" y="308" width="40" height="40"/>
  #|      </g>
  #|      <text class="service-label" x="2056" y="382" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|        <tspan x="2056" y="382">Internet</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="architecture-junction" data-id="hub">
  #|      <circle cx="1142" cy="350" r="8" fill="#64748b"/>
  #|    </g>
  #|  </g>
  #|  <text class="diagram-title" x="1098" y="24" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" fill="#111827">
  #|    <tspan x="1098" y="24">Offline architecture</tspan>
  #|  </text>
  #|</svg>

///|
let still_source_3 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 964 544" width="964" height="544" role="img" data-diagram="bpmn" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Plain,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="bpmn-6a2901c6600f6288-diagram">
  #|  <title>Review delivery</title>
  #|  <desc>BPMN view with 14 visible shapes and 9 connections. Structural flow is illustrative. Conditions, timers and execution outcomes are not evaluated.</desc>
  #|  <defs>
  #|    <marker id="bpmn-6a2901c6600f6288-sequence-head" viewBox="-12 -7 28 14" refX="0" refY="0" markerWidth="28" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-10 -5 L0 0 L-10 5 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|    </marker>
  #|    <marker id="bpmn-6a2901c6600f6288-open-head" viewBox="-12 -7 28 14" refX="0" refY="0" markerWidth="28" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-10 -5 L0 0 L-10 5" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|    </marker>
  #|    <marker id="bpmn-6a2901c6600f6288-message-tail" viewBox="-12 -7 28 14" refX="0" refY="0" markerWidth="28" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <circle cx="0" cy="0" r="3.5" fill="#f4f5f7" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="bpmn-6a2901c6600f6288-condition-tail" viewBox="-12 -7 28 14" refX="0" refY="0" markerWidth="28" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto">
  #|      <path d="M0 0 L6 -4 L12 0 L6 4 Z" fill="#f4f5f7" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|    </marker>
  #|    <marker id="bpmn-6a2901c6600f6288-default-tail" viewBox="-12 -7 28 14" refX="0" refY="0" markerWidth="28" markerHeight="14" markerUnits="userSpaceOnUse" orient="auto">
  #|      <path d="M4 -5 L10 5" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="964" height="544" fill="#f4f5f7"/>
  #|  <g transform="translate(12 12)" class="bpmn-viewport">
  #|    <g class="bpmn-backgrounds">
  #|      <g data-id="Intake" data-source-id="Intake" data-source-path="0/1/0/0" id="bpmn-6a2901c6600f6288-node-0" class="bpmn-shape" data-kind="lane" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="20" y="20" width="900" height="250" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(20 20) scale(900 250)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="0" fill="#f4f5f7" stroke="#64748b" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(20 20)" class="bpmn-markers">
  #|          <path d="M30 0 V250" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="Dispatch" data-source-id="Dispatch" data-source-path="0/1/0/1" id="bpmn-6a2901c6600f6288-node-1" class="bpmn-shape" data-kind="lane" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="20" y="270" width="900" height="230" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(20 270) scale(900 230)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="0" fill="#f4f5f7" stroke="#64748b" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(20 270)" class="bpmn-markers">
  #|          <path d="M30 0 V230" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="ReviewGroup" data-source-id="ReviewGroup" data-source-path="0/1/19" id="bpmn-6a2901c6600f6288-node-12" class="bpmn-shape" data-kind="group" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="180" y="75" width="270" height="195" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(180 75) scale(270 195)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="4 3 1 3" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(180 75)" class="bpmn-markers"/>
  #|      </g>
  #|    </g>
  #|    <g class="bpmn-connections">
  #|      <g data-id="ReadRequest" data-source-id="ReadRequest" data-source-path="0/1/2/2" id="bpmn-6a2901c6600f6288-flow-0" class="bpmn-flow" data-kind="dataInputAssociation" data-from="Requests" data-to="Review">
  #|        <path class="bpmn-connector" d="M288 238 L288 252 L410 252 L410 190 L260 190 L260 180" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-dasharray="1 4" stroke-linecap="round" marker-end="url(#bpmn-6a2901c6600f6288-open-head)" data-connector-id="ReadRequest" data-connector-source="Requests" data-connector-target="Review" data-connector-route="M288 238 L288 252 L410 252 L410 190 L260 190 L260 180" data-connector-key="0"/>
  #|      </g>
  #|      <g data-id="Receive" data-source-id="Receive" data-source-path="0/1/12" id="bpmn-6a2901c6600f6288-flow-1" class="bpmn-flow" data-kind="sequenceFlow" data-from="Start" data-to="Review">
  #|        <path class="bpmn-connector" d="M136 138 L168 138 L168 140 L200 140" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="Receive" data-connector-source="Start" data-connector-target="Review" data-connector-route="M136 138 L168 138 L168 140 L200 140" data-connector-key="1"/>
  #|      </g>
  #|      <g data-id="Check" data-source-id="Check" data-source-path="0/1/13" id="bpmn-6a2901c6600f6288-flow-2" class="bpmn-flow" data-kind="sequenceFlow" data-from="Review" data-to="Decision">
  #|        <path class="bpmn-connector" d="M320 140 L380 140" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="Check" data-connector-source="Review" data-connector-target="Decision" data-connector-route="M320 140 L380 140" data-connector-key="2"/>
  #|      </g>
  #|      <g data-id="Accept" data-source-id="Accept" data-source-path="0/1/14" id="bpmn-6a2901c6600f6288-flow-3" class="bpmn-flow" data-kind="sequenceFlow" data-from="Decision" data-to="Send" data-condition="approved">
  #|        <path class="bpmn-connector" d="M400 160 L400 360 L500 360" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="Accept" data-connector-source="Decision" data-connector-target="Send" data-connector-route="M400 160 L400 360 L500 360" data-connector-key="3"/>
  #|      </g>
  #|      <g data-id="Reject" data-source-id="Reject" data-source-path="0/1/15" id="bpmn-6a2901c6600f6288-flow-4" class="bpmn-flow" data-kind="sequenceFlow" data-from="Decision" data-to="Declined">
  #|        <path class="bpmn-connector" d="M420 140 L740 140" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" marker-start="url(#bpmn-6a2901c6600f6288-default-tail)" data-connector-id="Reject" data-connector-source="Decision" data-connector-target="Declined" data-connector-route="M420 140 L740 140" data-connector-key="4"/>
  #|      </g>
  #|      <g data-id="Deliver" data-source-id="Deliver" data-source-path="0/1/16" id="bpmn-6a2901c6600f6288-flow-5" class="bpmn-flow" data-kind="sequenceFlow" data-from="Send" data-to="Sent">
  #|        <path class="bpmn-connector" d="M640 360 L740 360" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="Deliver" data-connector-source="Send" data-connector-target="Sent" data-connector-route="M640 360 L740 360" data-connector-key="5"/>
  #|      </g>
  #|      <g data-id="Remind" data-source-id="Remind" data-source-path="0/1/17" id="bpmn-6a2901c6600f6288-flow-6" class="bpmn-flow" data-kind="sequenceFlow" data-from="Reminder" data-to="Notify">
  #|        <path class="bpmn-connector" d="M580 420 L580 470 L60 470 L60 380 L100 380" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="Remind" data-connector-source="Reminder" data-connector-target="Notify" data-connector-route="M580 420 L580 470 L60 470 L60 380 L100 380" data-connector-key="6"/>
  #|      </g>
  #|      <g data-id="FinishNotice" data-source-id="FinishNotice" data-source-path="0/1/18" id="bpmn-6a2901c6600f6288-flow-7" class="bpmn-flow" data-kind="sequenceFlow" data-from="Notify" data-to="Notified">
  #|        <path class="bpmn-connector" d="M240 380 L270 380 L270 360 L300 360" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" marker-end="url(#bpmn-6a2901c6600f6288-sequence-head)" data-connector-id="FinishNotice" data-connector-source="Notify" data-connector-target="Notified" data-connector-route="M240 380 L270 380 L270 360 L300 360" data-connector-key="7"/>
  #|      </g>
  #|      <g data-id="AuditLink" data-source-id="AuditLink" data-source-path="0/1/21" id="bpmn-6a2901c6600f6288-flow-8" class="bpmn-flow" data-kind="association" data-from="Review" data-to="Audit">
  #|        <path class="bpmn-connector" d="M320 160 L345 160 L345 185 L480 185 L480 224 L500 224" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-dasharray="1 4" stroke-linecap="round" data-connector-id="AuditLink" data-connector-source="Review" data-connector-target="Audit" data-connector-route="M320 160 L345 160 L345 185 L480 185 L480 224 L500 224" data-connector-key="8"/>
  #|      </g>
  #|    </g>
  #|    <g class="bpmn-nodes">
  #|      <g data-id="Start" data-source-id="Start" data-source-path="0/1/1" id="bpmn-6a2901c6600f6288-node-2" class="bpmn-shape" data-kind="startEvent" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="100" y="120" width="36" height="36" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(100 120) scale(36 36)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <circle cx="50" cy="50" r="50" fill="#f4f5f7" stroke="#ea580c" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(100 120)" class="bpmn-markers">
  #|          <g transform="translate(8.1 8.1) scale(0.825)"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="Review" data-source-id="Review" data-source-path="0/1/2" id="bpmn-6a2901c6600f6288-node-3" class="bpmn-shape" data-kind="userTask" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="200" y="100" width="120" height="80" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(200 100) scale(120 80)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="#f4f5f7" stroke="none" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(200 100)" class="bpmn-markers">
  #|          <g transform="translate(10 8) scale(0.8)">
  #|            <circle cx="12" cy="5" r="4" fill="none" stroke="#0891b2" stroke-width="1.5"/>
  #|            <path d="M4 23 V18 Q4 12 12 12 Q20 12 20 18 V23 M8 16 V23 M16 16 V23" fill="none" stroke="#0891b2" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Decision" data-source-id="Decision" data-source-path="0/1/3" id="bpmn-6a2901c6600f6288-node-4" class="bpmn-shape" data-kind="exclusiveGateway" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="380" y="120" width="40" height="40" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(380 120) scale(40 40)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <path d="M50 0 L100 50 L50 100 L0 50 Z" fill="#f4f5f7" stroke="#d97706" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(380 120)" class="bpmn-markers">
  #|          <g transform="translate(9 9) scale(0.917)">
  #|            <path d="M3 3 L21 21 M21 3 L3 21" fill="none" stroke="#d97706" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Declined" data-source-id="Declined" data-source-path="0/1/4" id="bpmn-6a2901c6600f6288-node-5" class="bpmn-shape" data-kind="endEvent" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="740" y="122" width="36" height="36" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(740 122) scale(36 36)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <circle cx="50" cy="50" r="50" fill="#f4f5f7" stroke="#ea580c" stroke-width="4" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(740 122)" class="bpmn-markers">
  #|          <g transform="translate(8.1 8.1) scale(0.825)"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="Send" data-source-id="Send" data-source-path="0/1/5" id="bpmn-6a2901c6600f6288-node-6" class="bpmn-shape" data-kind="serviceTask" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="500" y="320" width="140" height="80" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(500 320) scale(140 80)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="#f4f5f7" stroke="none" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(500 320)" class="bpmn-markers">
  #|          <g transform="translate(10 8) scale(0.8)">
  #|            <path d="M9 1 H15 L16 5 L19 7 L23 7 L24 13 L20 15 L19 18 L19 22 L13 24 L10 20 L7 19 L3 20 L1 14 L5 11 L5 8 L4 4 Z" fill="#f4f5f7" stroke="#059669" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <circle cx="12" cy="12" r="4" fill="none" stroke="#059669" stroke-width="1.5"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Reminder" data-source-id="Reminder" data-source-path="0/1/6" id="bpmn-6a2901c6600f6288-node-7" class="bpmn-shape" data-kind="boundaryEvent" data-expanded="false" data-black-box="false" data-attached-to="Send" data-events="timer">
  #|        <rect class="bpmn-bounds" x="560" y="380" width="40" height="40" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(560 380) scale(40 40)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <circle cx="50" cy="50" r="50" fill="#f4f5f7" stroke="#ea580c" stroke-width="1.5" stroke-dasharray="4 3" vector-effect="non-scaling-stroke"/>
  #|            <circle cx="50" cy="50" r="40" fill="none" stroke="#ea580c" stroke-width="1.5" stroke-dasharray="4 3" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(560 380)" class="bpmn-markers">
  #|          <g transform="translate(9 9) scale(0.917)">
  #|            <circle cx="12" cy="12" r="10.5" fill="none" stroke="#ea580c" stroke-width="1.5"/>
  #|            <path d="M12 5 V12 L17 15" fill="none" stroke="#ea580c" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M12 2 L12 4" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M12 20 L12 22" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M2 12 L4 12" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M20 12 L22 12" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M5 5 L6 6" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M18 18 L19 19" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M5 19 L6 18" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|            <path d="M18 6 L19 5" fill="none" stroke="#ea580c" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Notify" data-source-id="Notify" data-source-path="0/1/7" id="bpmn-6a2901c6600f6288-node-8" class="bpmn-shape" data-kind="userTask" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="100" y="340" width="140" height="80" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(100 340) scale(140 80)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="#f4f5f7" stroke="none" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|            <rect x="0" y="0" width="100" height="80" rx="10" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(100 340)" class="bpmn-markers">
  #|          <g transform="translate(10 8) scale(0.8)">
  #|            <circle cx="12" cy="5" r="4" fill="none" stroke="#0891b2" stroke-width="1.5"/>
  #|            <path d="M4 23 V18 Q4 12 12 12 Q20 12 20 18 V23 M8 16 V23 M16 16 V23" fill="none" stroke="#0891b2" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Sent" data-source-id="Sent" data-source-path="0/1/8" id="bpmn-6a2901c6600f6288-node-9" class="bpmn-shape" data-kind="endEvent" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="740" y="342" width="36" height="36" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(740 342) scale(36 36)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <circle cx="50" cy="50" r="50" fill="#f4f5f7" stroke="#ea580c" stroke-width="4" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(740 342)" class="bpmn-markers">
  #|          <g transform="translate(8.1 8.1) scale(0.825)"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="Notified" data-source-id="Notified" data-source-path="0/1/9" id="bpmn-6a2901c6600f6288-node-10" class="bpmn-shape" data-kind="endEvent" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="300" y="342" width="36" height="36" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(300 342) scale(36 36)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.01)">
  #|            <circle cx="50" cy="50" r="50" fill="#f4f5f7" stroke="#ea580c" stroke-width="4" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(300 342)" class="bpmn-markers">
  #|          <g transform="translate(8.1 8.1) scale(0.825)"/>
  #|        </g>
  #|      </g>
  #|      <g data-id="Requests" data-source-id="Requests" data-source-path="0/1/11" id="bpmn-6a2901c6600f6288-node-11" class="bpmn-shape" data-kind="dataObjectReference" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="270" y="190" width="36" height="48" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(270 190) scale(36 48)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <path d="M0 0 H75 L100 20 V80 H0 Z M75 0 V20 H100" fill="#f4f5f7" stroke="#7c3aed" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(270 190)" class="bpmn-markers">
  #|          <g transform="translate(10 31) scale(0.6)">
  #|            <path d="M5 3 V21 M12 3 V21 M19 3 V21" fill="none" stroke="#7c3aed" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
  #|          </g>
  #|        </g>
  #|      </g>
  #|      <g data-id="Audit" data-source-id="Audit" data-source-path="0/1/20" id="bpmn-6a2901c6600f6288-node-13" class="bpmn-shape" data-kind="textAnnotation" data-expanded="false" data-black-box="false" data-events="">
  #|        <rect class="bpmn-bounds" x="500" y="200" width="180" height="48" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|        <g transform="translate(500 200) scale(180 48)" aria-hidden="true">
  #|          <g transform="scale(0.01 0.0125)">
  #|            <path d="M12 0 H0 V80 H12" fill="none" stroke="#64748b" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>
  #|          </g>
  #|        </g>
  #|        <g transform="translate(500 200)" class="bpmn-markers"/>
  #|      </g>
  #|    </g>
  #|    <g class="bpmn-labels">
  #|      <g class="bpmn-label" data-owner="Intake">
  #|        <rect x="26" y="121" width="17" height="48" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <g transform="rotate(-90 34.5 145)">
  #|          <text x="34.5" y="149.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5a687c">Intake</text>
  #|        </g>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Dispatch">
  #|        <rect x="26" y="353" width="17" height="64" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <g transform="rotate(-90 34.5 385)">
  #|          <text x="34.5" y="389.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5a687c">Delivery</text>
  #|        </g>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Start">
  #|        <rect x="98" y="164" width="40" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="118" y="177" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">Start</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Review">
  #|        <text x="260" y="144.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#07718b">Review</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Decision">
  #|        <rect x="360" y="86" width="90" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="405" y="99.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#9d5705">Approved?</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Declined">
  #|        <rect x="726" y="166" width="64" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="758" y="179" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">Declined</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Send">
  #|        <text x="570" y="364.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">Dispatch</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Reminder">
  #|        <rect x="620" y="410" width="80" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="660" y="423.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">Reminder</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Notify">
  #|        <text x="170" y="384.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#07718b">Notify owner</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Sent">
  #|        <rect x="742" y="386" width="32" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="758" y="399" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">Sent</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Notified">
  #|        <rect x="286" y="386" width="64" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="318" y="399" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">Notified</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Requests">
  #|        <rect x="315" y="210" width="75" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="352.5" y="223.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#7935ed">Requests</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="ReviewGroup">
  #|        <rect x="192" y="50" width="48" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="216" y="63" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5a687c">Review</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Audit">
  #|        <rect x="518" y="215.5" width="144" height="17" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="590" y="228.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5a687c">Recorded for audit</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Receive">
  #|        <rect x="120" y="90" width="58" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="149" y="103.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">request</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Accept">
  #|        <rect x="425" y="285" width="75" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="462.5" y="298.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">approved</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Reject">
  #|        <rect x="550" y="112" width="70" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="585" y="125.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">rejected</text>
  #|      </g>
  #|      <g class="bpmn-label" data-owner="Remind">
  #|        <rect x="300" y="475" width="100" height="18" rx="0" fill="#f4f5f7" stroke="none" stroke-width="1.5"/>
  #|        <text x="350" y="488.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">remind</text>
  #|      </g>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_4 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 683 549" width="683" height="549" role="img" data-diagram="swimlane" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="sl-da0159bab19cd2c-diagram">
  #|  <title>Review</title>
  #|  <desc>Swimlane diagram with 2 responsibility lanes and 5 structural connections. Playback illustrates structure and does not execute a process.</desc>
  #|  <defs>
  #|    <marker id="sl-da0159bab19cd2c-sl-arrow" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-da0159bab19cd2c-sl-circle" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 0 A4 4 0 1 0 4 0 A4 4 0 1 0 -4 0 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-da0159bab19cd2c-sl-cross" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 -4 L4 4 M-4 4 L4 -4" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="683" height="549" fill="#f4f5f7"/>
  #|  <g class="swimlane-backgrounds">
  #|    <g class="swimlane-lane" data-swimlane-id="Support" data-shape="rect" data-expanded="true" data-lane="Support">
  #|      <rect class="swimlane-bounds" x="32" y="265" width="618.219" height="251.219" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="swimlane-outline" d="M32 265 L650.219 265 L650.219 516.219 L32 516.219 Z" fill="#f4f5f7" stroke="#5b6474" stroke-width="2"/>
  #|      <text class="swimlane-label" data-label-owner="Support" x="104" y="290" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|        <tspan x="104" y="290">Support review</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-lane" data-swimlane-id="Customer" data-shape="rect" data-expanded="true" data-lane="Customer">
  #|      <rect class="swimlane-bounds" x="32" y="32" width="618.219" height="201" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="swimlane-outline" d="M32 32 L650.219 32 L650.219 233 L32 233 Z" fill="#f4f5f7" stroke="#5b6474" stroke-width="2"/>
  #|      <text class="swimlane-label" data-label-owner="Customer" x="180" y="57" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|        <tspan x="180" y="57">Customer requests and corrections</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="swimlane-connections">
  #|    <g class="swimlane-connection" data-swimlane-id="AB" data-source="A" data-target="B" data-display-source="A" data-display-target="B">
  #|      <path class="swimlane-connector" d="M88 173.955 L88 205.955 L42 205.955 L42 346 L88 346 L88 386.889" fill="none" stroke="#64748b" stroke-width="1.5" marker-start="url(#sl-da0159bab19cd2c-sl-arrow)" marker-end="url(#sl-da0159bab19cd2c-sl-arrow)" data-connector-id="AB" data-connector-source="A" data-connector-target="B" data-connector-route="M88 173.955 L88 205.955 L42 205.955 L42 346 L88 346 L88 386.889" data-connector-key="0"/>
  #|      <rect x="168" y="265.477" width="136" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="swimlane-label" data-label-owner="AB" x="236" y="280.477" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="236" y="280.477">review or return</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-connection" data-swimlane-id="BC" data-source="B" data-target="C" data-display-source="B" data-display-target="C">
  #|      <path class="swimlane-connector" d="M224 391 L256 391 L256 460.219 L516.092 460.219" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-da0159bab19cd2c-sl-arrow)" data-connector-id="BC" data-connector-source="B" data-connector-target="C" data-connector-route="M224 391 L256 391 L256 460.219 L516.092 460.219" data-connector-key="1"/>
  #|      <rect x="354.046" y="431.219" width="64" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="swimlane-label" data-label-owner="BC" x="386.046" y="446.219" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="386.046" y="446.219">approve</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-connection" data-swimlane-id="CA" data-source="C" data-target="A" data-display-source="C" data-display-target="A">
  #|      <path class="swimlane-connector" d="M516.092 362 L480 362 L480 129 L180.955 129" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="CA" data-connector-source="C" data-connector-target="A" data-connector-route="M516.092 362 L480 362 L480 129 L180.955 129" data-connector-key="2"/>
  #|      <rect x="298.477" y="100" width="64" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="swimlane-label" data-label-owner="CA" x="330.477" y="115" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="330.477" y="115">related</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-connection" data-swimlane-id="parallel" data-source="A" data-target="B" data-display-source="A" data-display-target="B">
  #|      <path class="swimlane-connector" d="M184 173.955 L184 213.955 L166 213.955 L166 346 L216 346 L216 386.889" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="4 4" marker-end="url(#sl-da0159bab19cd2c-sl-arrow)" data-connector-id="parallel" data-connector-source="A" data-connector-target="B" data-connector-route="M184 173.955 L184 213.955 L166 213.955 L166 346 L216 346 L216 386.889" data-connector-key="3"/>
  #|      <rect x="130" y="226.977" width="72" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="swimlane-label" data-label-owner="parallel" x="166" y="241.977" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="166" y="241.977">expedite</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="swimlane-nodes">
  #|    <g class="swimlane-node" data-swimlane-id="A" data-shape="stadium" data-expanded="true" data-lane="Customer" data-parent="Customer">
  #|      <rect class="swimlane-bounds" x="80" y="121" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="swimlane-outline" d="M160 121 L166.243 121.615 L172.246 123.436 L177.778 126.393 L182.627 130.373 L186.607 135.222 L189.564 140.754 L191.385 146.757 L192 153 L192 153 L191.385 159.243 L189.564 165.246 L186.607 170.778 L182.627 175.627 L177.778 179.607 L172.246 182.564 L166.243 184.385 L160 185 L112 185 L105.757 184.385 L99.754 182.564 L94.222 179.607 L89.373 175.627 L85.393 170.778 L82.436 165.246 L80.615 159.243 L80 153 L80 153 L80.615 146.757 L82.436 140.754 L85.393 135.222 L89.373 130.373 L94.222 126.393 L99.754 123.436 L105.757 121.615 L112 121 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="swimlane-label" data-label-owner="A" x="136" y="157.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="136" y="157.5">Request</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-node" data-swimlane-id="B" data-shape="diamond" data-expanded="true" data-lane="Support" data-parent="Support">
  #|      <rect class="swimlane-bounds" x="80" y="354" width="144" height="74" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="swimlane-outline" d="M152 354 L224 391 L152 428 L80 391 Z" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="swimlane-label" data-label-owner="B" x="152" y="395.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#9d5705">
  #|        <tspan x="152" y="395.5">Review</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="swimlane-node" data-swimlane-id="C" data-shape="circle" data-expanded="true" data-lane="Support" data-parent="Support">
  #|      <rect class="swimlane-bounds" x="488" y="354" width="114.219" height="114.219" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="swimlane-outline" d="M602.219 411.11 L601.944 416.707 L601.122 422.251 L599.76 427.688 L597.872 432.965 L595.476 438.031 L592.595 442.838 L589.256 447.34 L585.492 451.492 L581.34 455.256 L576.838 458.595 L572.031 461.476 L566.965 463.872 L561.688 465.76 L556.251 467.122 L550.707 467.944 L545.11 468.219 L539.512 467.944 L533.968 467.122 L528.532 465.76 L523.255 463.872 L518.188 461.476 L513.381 458.595 L508.88 455.256 L504.727 451.492 L500.963 447.34 L497.625 442.838 L494.743 438.031 L492.347 432.965 L490.459 427.688 L489.097 422.251 L488.275 416.707 L488 411.11 L488.275 405.512 L489.097 399.968 L490.459 394.532 L492.347 389.255 L494.743 384.188 L497.625 379.381 L500.963 374.88 L504.727 370.727 L508.88 366.963 L513.381 363.625 L518.188 360.743 L523.255 358.347 L528.532 356.459 L533.968 355.097 L539.512 354.275 L545.11 354 L550.707 354.275 L556.251 355.097 L561.688 356.459 L566.965 358.347 L572.031 360.743 L576.838 363.625 L581.34 366.963 L585.492 370.727 L589.256 374.88 L592.595 379.381 L595.476 384.188 L597.872 389.255 L599.76 394.532 L601.122 399.968 L601.944 405.512 L602.219 411.11 Z" fill="rgba(251, 146, 60, 0.15)" stroke="#ea580c" stroke-width="1.5"/>
  #|      <text class="swimlane-label" data-label-owner="C" x="545.11" y="415.61" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#b44409">
  #|        <tspan x="545.11" y="415.61">Complete</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_5 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1344 684" width="1344" height="684" role="img" data-diagram="flowchart" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-diagram">
  #|  <title>Request validation and retry</title>
  #|  <desc>Structural branches and a return path, without condition evaluation</desc>
  #|  <defs>
  #|    <marker id="sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-arrow" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-circle" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 0 A4 4 0 1 0 4 0 A4 4 0 1 0 -4 0 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-cross" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 -4 L4 4 M-4 4 L4 -4" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="1344" height="684" fill="#f4f5f7"/>
  #|  <g class="flowchart-backgrounds">
  #|    <g class="flowchart-group" data-flowchart-id="Intake" data-shape="rect" data-expanded="true">
  #|      <rect class="flowchart-bounds" x="80" y="80" width="688" height="348" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M80 80 L768 80 L768 428 L80 428 Z" fill="#f4f5f7" stroke="#5b6474" stroke-width="1.5" stroke-dasharray="6 4"/>
  #|      <text class="flowchart-label" data-label-owner="Intake" x="120" y="105" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|        <tspan x="120" y="105">Intake</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-group" data-flowchart-id="Validation" data-shape="rect" data-expanded="true" data-parent="Intake">
  #|      <rect class="flowchart-bounds" x="128" y="169" width="592" height="211" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M128 169 L720 169 L720 380 L128 380 Z" fill="#f4f5f7" stroke="#5b6474" stroke-width="1.5" stroke-dasharray="6 4"/>
  #|      <text class="flowchart-label" data-label-owner="Validation" x="184" y="194" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|        <tspan x="184" y="194">Validation</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="flowchart-connections">
  #|    <g class="flowchart-connection" data-flowchart-id="L_Read_Complete_0" data-source="Read" data-target="Complete" data-display-source="Read" data-display-target="Complete">
  #|      <path class="flowchart-connector" d="M320 290 L448 290 L448 295 L480 295" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="L_Read_Complete_0" data-connector-source="Read" data-connector-target="Complete" data-connector-route="M320 290 L448 290 L448 295 L480 295" data-connector-key="0"/>
  #|    </g>
  #|    <g class="flowchart-connection" data-flowchart-id="L_Complete_Save_0" data-source="Complete" data-target="Save" data-display-source="Complete" data-display-target="Save">
  #|      <path class="flowchart-connector" d="M672 295 L896 295 L896 112 L928 112" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="L_Complete_Save_0" data-connector-source="Complete" data-connector-target="Save" data-connector-route="M672 295 L896 295 L896 112 L928 112" data-connector-key="1"/>
  #|      <rect x="768" y="266" width="32" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="flowchart-label" data-label-owner="L_Complete_Save_0" x="784" y="281" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="784" y="281">yes</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-connection" data-flowchart-id="L_Complete_Read_0" data-source="Complete" data-target="Read" data-display-source="Complete" data-display-target="Read">
  #|      <path class="flowchart-connector" d="M576 258 L576 226 L248 226 L248 258" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="L_Complete_Read_0" data-connector-source="Complete" data-connector-target="Read" data-connector-route="M576 258 L576 226 L248 226 L248 258" data-connector-key="2"/>
  #|      <rect x="400" y="197" width="24" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="flowchart-label" data-label-owner="L_Complete_Read_0" x="412" y="212" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="412" y="212">no</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-connection" data-flowchart-id="L_Save_Notify_0" data-source="Save" data-target="Notify" data-display-source="Save" data-display-target="Notify">
  #|      <path class="flowchart-connector" d="M1040 112 L1200 112" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-66-6c-6f-77-63-68-61-72-74-2d-6d-65-72-6d-61-69-64-2d-72-65-76-69-65-77-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="L_Save_Notify_0" data-connector-source="Save" data-connector-target="Notify" data-connector-route="M1040 112 L1200 112" data-connector-key="3"/>
  #|    </g>
  #|  </g>
  #|  <g class="flowchart-nodes">
  #|    <g class="flowchart-node" data-flowchart-id="Read" data-shape="rect" data-expanded="true" data-parent="Validation">
  #|      <rect class="flowchart-bounds" x="176" y="258" width="144" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M176 258 L320 258 L320 322 L176 322 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="flowchart-label" data-label-owner="Read" x="248" y="294.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="248" y="294.5">Read request</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-node" data-flowchart-id="Complete" data-shape="diamond" data-expanded="true" data-parent="Validation">
  #|      <rect class="flowchart-bounds" x="480" y="258" width="192" height="74" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M576 258 L672 295 L576 332 L480 295 Z" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="flowchart-label" data-label-owner="Complete" x="576" y="299.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#9d5705">
  #|        <tspan x="576" y="299.5">Complete?</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-node" data-flowchart-id="Save" data-shape="rect" data-expanded="true">
  #|      <rect class="flowchart-bounds" x="928" y="80" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M928 80 L1040 80 L1040 144 L928 144 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="flowchart-label" data-label-owner="Save" x="984" y="116.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="984" y="116.5">Save</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-node" data-flowchart-id="Notify" data-shape="rect" data-expanded="true">
  #|      <rect class="flowchart-bounds" x="1200" y="80" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M1200 80 L1312 80 L1312 144 L1200 144 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="flowchart-label" data-label-owner="Notify" x="1256" y="116.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="1256" y="116.5">Notify</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="flowchart-node" data-flowchart-id="Inspect" data-shape="rect" data-expanded="true">
  #|      <rect class="flowchart-bounds" x="80" y="588" width="184" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="flowchart-outline" d="M80 588 L264 588 L264 652 L80 652 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="flowchart-label" data-label-owner="Inspect" x="172" y="624.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="172" y="624.5">Manual inspection</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_6 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 926 349" width="926" height="349" role="img" data-diagram="regex" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="rr-245603e63cee7815-diagram">
  #|  <title>ISO date with optional time</title>
  #|  <desc>Railroad diagram of the regular expression (?&lt;year&gt;\d{4})-(?&lt;month&gt;0[1-9]|1[0-2])-(?&lt;day&gt;\d{2})(?:T\d{2}:\d{2})?(?!\d) with 14 terms. It shows structure; it does not match input.</desc>
  #|  <defs>
  #|    <marker id="rr-245603e63cee7815-rr-return" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="12" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-8 -4 L0 0 L-8 4 Z" fill="#64748b" stroke="none"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="926" height="349" fill="#f4f5f7"/>
  #|  <g class="rr-title">
  #|    <text class="rr-title-text" x="463" y="34" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="16" font-weight="700" fill="#111827">
  #|      <tspan x="463" y="34">ISO date with optional time</tspan>
  #|    </text>
  #|  </g>
  #|  <g class="rr-notes"/>
  #|  <g class="rr-frames">
  #|    <g class="rr-frame rr-group" data-owner="p.0">
  #|      <rect class="rr-frame-box" x="50" y="76" width="192" height="99" rx="8" fill="none" stroke="#5b6474" stroke-width="1.2" stroke-dasharray="5 4"/>
  #|      <text class="rr-frame-label" x="146" y="87" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="146" y="87">group year</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-frame rr-group" data-owner="p.2">
  #|      <rect class="rr-frame-box" x="310" y="76" width="304" height="109" rx="8" fill="none" stroke="#5b6474" stroke-width="1.2" stroke-dasharray="5 4"/>
  #|      <text class="rr-frame-label" x="462" y="87" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="462" y="87">group month</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-frame rr-group" data-owner="p.4">
  #|      <rect class="rr-frame-box" x="682" y="76" width="192" height="99" rx="8" fill="none" stroke="#5b6474" stroke-width="1.2" stroke-dasharray="5 4"/>
  #|      <text class="rr-frame-label" x="778" y="87" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="778" y="87">group day</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-frame rr-group" data-owner="p.5.0">
  #|      <rect class="rr-frame-box" x="114" y="221" width="472" height="99" rx="8" fill="none" stroke="#5b6474" stroke-width="1.2" stroke-dasharray="5 4"/>
  #|      <text class="rr-frame-label" x="350" y="232" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="350" y="232">non-capturing group</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="rr-connectors">
  #|    <path class="rr-connector rr-start" data-connector="c5:regex:start" data-role="start" data-owner="regex" d="M30 118.5 L50 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:regex:start" data-connector-source="" data-connector-target="" data-connector-route="M30 118.5 L50 118.5" data-connector-key="0"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.1:gap" data-role="gap" data-owner="p.1" d="M242 118.5 L262 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M242 118.5 L262 118.5" data-connector-key="1"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.2:gap" data-role="gap" data-owner="p.2" d="M290 118.5 L310 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.2:gap" data-connector-source="" data-connector-target="" data-connector-route="M290 118.5 L310 118.5" data-connector-key="2"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.3:gap" data-role="gap" data-owner="p.3" d="M614 118.5 L634 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.3:gap" data-connector-source="" data-connector-target="" data-connector-route="M614 118.5 L634 118.5" data-connector-key="3"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.4:gap" data-role="gap" data-owner="p.4" d="M662 118.5 L682 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.4:gap" data-connector-source="" data-connector-target="" data-connector-route="M662 118.5 L682 118.5" data-connector-key="4"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.5:gap" data-role="gap" data-owner="p.5" d="M874 118.5 L898 118.5 Q906 118.5 906 126.5 L906 189 Q906 197 898 197 L26 197 Q18 197 18 205 L18 255.5 Q18 263.5 26 263.5 L50 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.5:gap" data-connector-source="" data-connector-target="" data-connector-route="M874 118.5 L898 118.5 Q906 118.5 906 126.5 L906 189 Q906 197 898 197 L26 197 Q18 197 18 205 L18 255.5 Q18 263.5 26 263.5 L50 263.5" data-connector-key="5"/>
  #|    <path class="rr-connector rr-gap" data-connector="c3:p.6:gap" data-role="gap" data-owner="p.6" d="M650 263.5 L670 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.6:gap" data-connector-source="" data-connector-target="" data-connector-route="M650 263.5 L670 263.5" data-connector-key="6"/>
  #|    <path class="rr-connector rr-enter" data-connector="c3:p.0:enter" data-role="enter" data-owner="p.0" d="M50 118.5 L64 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.0:enter" data-connector-source="" data-connector-target="" data-connector-route="M50 118.5 L64 118.5" data-connector-key="7"/>
  #|    <path class="rr-connector rr-leave" data-connector="c3:p.0:leave" data-role="leave" data-owner="p.0" d="M228 118.5 L242 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.0:leave" data-connector-source="" data-connector-target="" data-connector-route="M228 118.5 L242 118.5" data-connector-key="8"/>
  #|    <path class="rr-connector rr-enter" data-connector="c5:p.0.0:enter" data-role="enter" data-owner="p.0.0" d="M64 118.5 L128 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.0.0:enter" data-connector-source="" data-connector-target="" data-connector-route="M64 118.5 L128 118.5" data-connector-key="9"/>
  #|    <path class="rr-connector rr-leave" data-connector="c5:p.0.0:leave" data-role="leave" data-owner="p.0.0" d="M164 118.5 L228 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.0.0:leave" data-connector-source="" data-connector-target="" data-connector-route="M164 118.5 L228 118.5" data-connector-key="10"/>
  #|    <g class="rr-wire">
  #|      <path class="rr-connector rr-return" data-connector="c5:p.0.0:return" data-role="return" data-owner="p.0.0" d="M164 118.5 L188 118.5 Q196 118.5 196 126.5 L196 136 Q196 144 188 144 L104 144 Q96 144 96 136 L96 126.5 Q96 118.5 104 118.5 L128 118.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-245603e63cee7815-rr-return)" data-connector-id="c5:p.0.0:return" data-connector-source="" data-connector-target="" data-connector-route="M164 118.5 L188 118.5 Q196 118.5 196 126.5 L196 136 Q196 144 188 144 L104 144 Q96 144 96 136 L96 126.5 Q96 118.5 104 118.5 L128 118.5" data-connector-key="11"/>
  #|      <text class="rr-bounds" x="146" y="155" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="146" y="155">{4}</tspan>
  #|      </text>
  #|    </g>
  #|    <path class="rr-connector rr-enter" data-connector="c3:p.2:enter" data-role="enter" data-owner="p.2" d="M310 118.5 L324 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.2:enter" data-connector-source="" data-connector-target="" data-connector-route="M310 118.5 L324 118.5" data-connector-key="12"/>
  #|    <path class="rr-connector rr-leave" data-connector="c3:p.2:leave" data-role="leave" data-owner="p.2" d="M600 118.5 L614 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.2:leave" data-connector-source="" data-connector-target="" data-connector-route="M600 118.5 L614 118.5" data-connector-key="13"/>
  #|    <path class="rr-connector rr-split-0" data-connector="c5:p.2.0:split-0" data-role="split-0" data-owner="p.2.0" d="M324 118.5 L388 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.2.0:split-0" data-connector-source="" data-connector-target="" data-connector-route="M324 118.5 L388 118.5" data-connector-key="14"/>
  #|    <path class="rr-connector rr-join-0" data-connector="c5:p.2.0:join-0" data-role="join-0" data-owner="p.2.0" d="M536 118.5 L600 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.2.0:join-0" data-connector-source="" data-connector-target="" data-connector-route="M536 118.5 L600 118.5" data-connector-key="15"/>
  #|    <path class="rr-connector rr-split-1" data-connector="c5:p.2.0:split-1" data-role="split-1" data-owner="p.2.0" d="M324 118.5 L348 118.5 Q356 118.5 356 126.5 L356 149.5 Q356 157.5 364 157.5 L388 157.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.2.0:split-1" data-connector-source="" data-connector-target="" data-connector-route="M324 118.5 L348 118.5 Q356 118.5 356 126.5 L356 149.5 Q356 157.5 364 157.5 L388 157.5" data-connector-key="16"/>
  #|    <path class="rr-connector rr-join-1" data-connector="c5:p.2.0:join-1" data-role="join-1" data-owner="p.2.0" d="M536 157.5 L560 157.5 Q568 157.5 568 149.5 L568 126.5 Q568 118.5 576 118.5 L600 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.2.0:join-1" data-connector-source="" data-connector-target="" data-connector-route="M536 157.5 L560 157.5 Q568 157.5 568 149.5 L568 126.5 Q568 118.5 576 118.5 L600 118.5" data-connector-key="17"/>
  #|    <path class="rr-connector rr-gap" data-connector="c9:p.2.0.0.1:gap" data-role="gap" data-owner="p.2.0.0.1" d="M416 118.5 L436 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.2.0.0.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M416 118.5 L436 118.5" data-connector-key="18"/>
  #|    <path class="rr-connector rr-gap" data-connector="c9:p.2.0.1.1:gap" data-role="gap" data-owner="p.2.0.1.1" d="M416 157.5 L436 157.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.2.0.1.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M416 157.5 L436 157.5" data-connector-key="19"/>
  #|    <path class="rr-connector rr-enter" data-connector="c3:p.4:enter" data-role="enter" data-owner="p.4" d="M682 118.5 L696 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.4:enter" data-connector-source="" data-connector-target="" data-connector-route="M682 118.5 L696 118.5" data-connector-key="20"/>
  #|    <path class="rr-connector rr-leave" data-connector="c3:p.4:leave" data-role="leave" data-owner="p.4" d="M860 118.5 L874 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.4:leave" data-connector-source="" data-connector-target="" data-connector-route="M860 118.5 L874 118.5" data-connector-key="21"/>
  #|    <path class="rr-connector rr-enter" data-connector="c5:p.4.0:enter" data-role="enter" data-owner="p.4.0" d="M696 118.5 L760 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.4.0:enter" data-connector-source="" data-connector-target="" data-connector-route="M696 118.5 L760 118.5" data-connector-key="22"/>
  #|    <path class="rr-connector rr-leave" data-connector="c5:p.4.0:leave" data-role="leave" data-owner="p.4.0" d="M796 118.5 L860 118.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.4.0:leave" data-connector-source="" data-connector-target="" data-connector-route="M796 118.5 L860 118.5" data-connector-key="23"/>
  #|    <g class="rr-wire">
  #|      <path class="rr-connector rr-return" data-connector="c5:p.4.0:return" data-role="return" data-owner="p.4.0" d="M796 118.5 L820 118.5 Q828 118.5 828 126.5 L828 136 Q828 144 820 144 L736 144 Q728 144 728 136 L728 126.5 Q728 118.5 736 118.5 L760 118.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-245603e63cee7815-rr-return)" data-connector-id="c5:p.4.0:return" data-connector-source="" data-connector-target="" data-connector-route="M796 118.5 L820 118.5 Q828 118.5 828 126.5 L828 136 Q828 144 820 144 L736 144 Q728 144 728 136 L728 126.5 Q728 118.5 736 118.5 L760 118.5" data-connector-key="24"/>
  #|      <text class="rr-bounds" x="778" y="155" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="778" y="155">{2}</tspan>
  #|      </text>
  #|    </g>
  #|    <path class="rr-connector rr-enter" data-connector="c3:p.5:enter" data-role="enter" data-owner="p.5" d="M50 263.5 L114 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.5:enter" data-connector-source="" data-connector-target="" data-connector-route="M50 263.5 L114 263.5" data-connector-key="25"/>
  #|    <path class="rr-connector rr-leave" data-connector="c3:p.5:leave" data-role="leave" data-owner="p.5" d="M586 263.5 L650 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.5:leave" data-connector-source="" data-connector-target="" data-connector-route="M586 263.5 L650 263.5" data-connector-key="26"/>
  #|    <path class="rr-connector rr-bypass" data-connector="c3:p.5:bypass" data-role="bypass" data-owner="p.5" d="M50 263.5 L74 263.5 Q82 263.5 82 255.5 L82 217 Q82 209 90 209 L610 209 Q618 209 618 217 L618 255.5 Q618 263.5 626 263.5 L650 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c3:p.5:bypass" data-connector-source="" data-connector-target="" data-connector-route="M50 263.5 L74 263.5 Q82 263.5 82 255.5 L82 217 Q82 209 90 209 L610 209 Q618 209 618 217 L618 255.5 Q618 263.5 626 263.5 L650 263.5" data-connector-key="27"/>
  #|    <path class="rr-connector rr-enter" data-connector="c5:p.5.0:enter" data-role="enter" data-owner="p.5.0" d="M114 263.5 L128 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.5.0:enter" data-connector-source="" data-connector-target="" data-connector-route="M114 263.5 L128 263.5" data-connector-key="28"/>
  #|    <path class="rr-connector rr-leave" data-connector="c5:p.5.0:leave" data-role="leave" data-owner="p.5.0" d="M572 263.5 L586 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:p.5.0:leave" data-connector-source="" data-connector-target="" data-connector-route="M572 263.5 L586 263.5" data-connector-key="29"/>
  #|    <path class="rr-connector rr-gap" data-connector="c9:p.5.0.0.1:gap" data-role="gap" data-owner="p.5.0.0.1" d="M156 263.5 L176 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M156 263.5 L176 263.5" data-connector-key="30"/>
  #|    <path class="rr-connector rr-gap" data-connector="c9:p.5.0.0.2:gap" data-role="gap" data-owner="p.5.0.0.2" d="M340 263.5 L360 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.2:gap" data-connector-source="" data-connector-target="" data-connector-route="M340 263.5 L360 263.5" data-connector-key="31"/>
  #|    <path class="rr-connector rr-gap" data-connector="c9:p.5.0.0.3:gap" data-role="gap" data-owner="p.5.0.0.3" d="M388 263.5 L408 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.3:gap" data-connector-source="" data-connector-target="" data-connector-route="M388 263.5 L408 263.5" data-connector-key="32"/>
  #|    <path class="rr-connector rr-enter" data-connector="c9:p.5.0.0.1:enter" data-role="enter" data-owner="p.5.0.0.1" d="M176 263.5 L240 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.1:enter" data-connector-source="" data-connector-target="" data-connector-route="M176 263.5 L240 263.5" data-connector-key="33"/>
  #|    <path class="rr-connector rr-leave" data-connector="c9:p.5.0.0.1:leave" data-role="leave" data-owner="p.5.0.0.1" d="M276 263.5 L340 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.1:leave" data-connector-source="" data-connector-target="" data-connector-route="M276 263.5 L340 263.5" data-connector-key="34"/>
  #|    <g class="rr-wire">
  #|      <path class="rr-connector rr-return" data-connector="c9:p.5.0.0.1:return" data-role="return" data-owner="p.5.0.0.1" d="M276 263.5 L300 263.5 Q308 263.5 308 271.5 L308 281 Q308 289 300 289 L216 289 Q208 289 208 281 L208 271.5 Q208 263.5 216 263.5 L240 263.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-245603e63cee7815-rr-return)" data-connector-id="c9:p.5.0.0.1:return" data-connector-source="" data-connector-target="" data-connector-route="M276 263.5 L300 263.5 Q308 263.5 308 271.5 L308 281 Q308 289 300 289 L216 289 Q208 289 208 281 L208 271.5 Q208 263.5 216 263.5 L240 263.5" data-connector-key="35"/>
  #|      <text class="rr-bounds" x="258" y="300" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="258" y="300">{2}</tspan>
  #|      </text>
  #|    </g>
  #|    <path class="rr-connector rr-enter" data-connector="c9:p.5.0.0.3:enter" data-role="enter" data-owner="p.5.0.0.3" d="M408 263.5 L472 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.3:enter" data-connector-source="" data-connector-target="" data-connector-route="M408 263.5 L472 263.5" data-connector-key="36"/>
  #|    <path class="rr-connector rr-leave" data-connector="c9:p.5.0.0.3:leave" data-role="leave" data-owner="p.5.0.0.3" d="M508 263.5 L572 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c9:p.5.0.0.3:leave" data-connector-source="" data-connector-target="" data-connector-route="M508 263.5 L572 263.5" data-connector-key="37"/>
  #|    <g class="rr-wire">
  #|      <path class="rr-connector rr-return" data-connector="c9:p.5.0.0.3:return" data-role="return" data-owner="p.5.0.0.3" d="M508 263.5 L532 263.5 Q540 263.5 540 271.5 L540 281 Q540 289 532 289 L448 289 Q440 289 440 281 L440 271.5 Q440 263.5 448 263.5 L472 263.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-245603e63cee7815-rr-return)" data-connector-id="c9:p.5.0.0.3:return" data-connector-source="" data-connector-target="" data-connector-route="M508 263.5 L532 263.5 Q540 263.5 540 271.5 L540 281 Q540 289 532 289 L448 289 Q440 289 440 281 L440 271.5 Q440 263.5 448 263.5 L472 263.5" data-connector-key="38"/>
  #|      <text class="rr-bounds" x="490" y="300" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="490" y="300">{2}</tspan>
  #|      </text>
  #|    </g>
  #|    <path class="rr-connector rr-enter" data-connector="c3:p.6:enter" data-role="enter" data-owner="p.6" d="M674 301 L684 301" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c3:p.6:enter" data-connector-source="" data-connector-target="" data-connector-route="M674 301 L684 301" data-connector-key="39"/>
  #|    <path class="rr-connector rr-leave" data-connector="c3:p.6:leave" data-role="leave" data-owner="p.6" d="M720 301 L837 301" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c3:p.6:leave" data-connector-source="" data-connector-target="" data-connector-route="M720 301 L837 301" data-connector-key="40"/>
  #|    <path class="rr-connector rr-end" data-connector="c5:regex:end" data-role="end" data-owner="regex" d="M841 263.5 L894 263.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c5:regex:end" data-connector-source="" data-connector-target="" data-connector-route="M841 263.5 L894 263.5" data-connector-key="41"/>
  #|  </g>
  #|  <g class="rr-terms">
  #|    <g class="rr-term rr-class" data-term="p.0.0.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="128" y="105" width="36" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="146" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="146" y="121">\d</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.1" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="262" y="105" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="276" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="276" y="121">-</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.2.0.0.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="388" y="105" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="402" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="402" y="121">0</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.2.0.0.1" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="436" y="105" width="100" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="486" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="486" y="121">one of 1-9</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.2.0.1.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="388" y="144" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="402" y="160" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="402" y="160">1</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.2.0.1.1" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="436" y="144" width="100" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="486" y="160" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="486" y="160">one of 0-2</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.3" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="634" y="105" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="648" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="648" y="121">-</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.4.0.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="760" y="105" width="36" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="778" y="121" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="778" y="121">\d</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.5.0.0.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="128" y="250" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="142" y="266" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="142" y="266">T</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.5.0.0.1.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="240" y="250" width="36" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="258" y="266" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="258" y="266">\d</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="p.5.0.0.2" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="360" y="250" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="374" y="266" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="374" y="266">:</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.5.0.0.3.0" data-role="consumed" data-rule="regex">
  #|      <rect class="rr-box" x="472" y="250" width="36" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="490" y="266" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="490" y="266">\d</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-lookaround" data-term="p.6" data-role="assertion" data-rule="regex">
  #|      <rect class="rr-box" x="670" y="253.5" width="171" height="75" rx="8" fill="rgba(148, 163, 184, 0.18)" stroke="#64748b" stroke-width="1.5" stroke-dasharray="6 4"/>
  #|      <text class="rr-label" x="755.5" y="264.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#5b6474">
  #|        <tspan x="755.5" y="264.5">negative lookahead ?!</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-class" data-term="p.6.0" data-role="consumed" data-rule="regex" data-constraint="true">
  #|      <rect class="rr-box" x="684" y="287.5" width="36" height="27" rx="6" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|      <text class="rr-label" x="702" y="303.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="702" y="303.5">\d</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="rr-tracks">
  #|    <g class="rr-track" data-rule="regex">
  #|      <text class="rr-rule-name" x="20" y="64" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="64">pattern</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="118.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="900" cy="263.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="900" cy="263.5" r="3" fill="#64748b"/>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_7 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 838" width="560" height="838" role="img" data-diagram="ebnf" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="rr-f6a65e5ef8c2bcff-diagram">
  #|  <title>Arithmetic with recursion</title>
  #|  <desc>Railroad diagram of a grammar with 5 rules and 19 terms. References are not expanded. It shows structure; it does not parse input.</desc>
  #|  <defs>
  #|    <marker id="rr-f6a65e5ef8c2bcff-rr-return" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="12" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-8 -4 L0 0 L-8 4 Z" fill="#64748b" stroke="none"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="560" height="838" fill="#f4f5f7"/>
  #|  <g class="rr-title">
  #|    <text class="rr-title-text" x="280" y="34" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="16" font-weight="700" fill="#111827">
  #|      <tspan x="280" y="34">Arithmetic with recursion</tspan>
  #|    </text>
  #|  </g>
  #|  <g class="rr-notes">
  #|    <g class="rr-note" data-note="item-0">
  #|      <rect class="rr-note-box" x="20" y="52" width="291" height="42" rx="4" fill="rgba(148, 163, 184, 0.18)" stroke="#64748b" stroke-width="1.5"/>
  #|      <text class="rr-note-text" x="165.5" y="67" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#111827">
  #|        <tspan x="165.5" y="67">Expressions refer to terms; parentheses </tspan>
  #|        <tspan x="165.5" y="82">refer back to expressions.</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="rr-frames">
  #|    <g class="rr-frame rr-except" data-owner="item-5/e.1">
  #|      <rect class="rr-frame-box" x="50" y="709" width="184" height="109" rx="8" fill="none" stroke="#e11d48" stroke-width="1.2" stroke-dasharray="5 4"/>
  #|      <text class="rr-frame-label" x="142" y="720" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="#d81c45">
  #|        <tspan x="142" y="720">except</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="rr-connectors">
  #|    <path class="rr-connector rr-start" data-connector="c6:item-1:start" data-role="start" data-owner="item-1" d="M30 167.5 L50 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-1:start" data-connector-source="" data-connector-target="" data-connector-route="M30 167.5 L50 167.5" data-connector-key="0"/>
  #|    <path class="rr-connector rr-gap" data-connector="c10:item-1/e.1:gap" data-role="gap" data-owner="item-1/e.1" d="M102 167.5 L122 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-1/e.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M102 167.5 L122 167.5" data-connector-key="1"/>
  #|    <path class="rr-connector rr-enter" data-connector="c10:item-1/e.1:enter" data-role="enter" data-owner="item-1/e.1" d="M122 167.5 L186 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-1/e.1:enter" data-connector-source="" data-connector-target="" data-connector-route="M122 167.5 L186 167.5" data-connector-key="2"/>
  #|    <path class="rr-connector rr-leave" data-connector="c10:item-1/e.1:leave" data-role="leave" data-owner="item-1/e.1" d="M414 167.5 L478 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-1/e.1:leave" data-connector-source="" data-connector-target="" data-connector-route="M414 167.5 L478 167.5" data-connector-key="3"/>
  #|    <path class="rr-connector rr-bypass" data-connector="c10:item-1/e.1:bypass" data-role="bypass" data-owner="item-1/e.1" d="M122 167.5 L146 167.5 Q154 167.5 154 159.5 L154 150 Q154 142 162 142 L438 142 Q446 142 446 150 L446 159.5 Q446 167.5 454 167.5 L478 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-1/e.1:bypass" data-connector-source="" data-connector-target="" data-connector-route="M122 167.5 L146 167.5 Q154 167.5 154 159.5 L154 150 Q154 142 162 142 L438 142 Q446 142 446 150 L446 159.5 Q446 167.5 454 167.5 L478 167.5" data-connector-key="4"/>
  #|    <path class="rr-connector rr-return" data-connector="c10:item-1/e.1:return" data-role="return" data-owner="item-1/e.1" d="M414 167.5 L438 167.5 Q446 167.5 446 175.5 L446 224 Q446 232 438 232 L162 232 Q154 232 154 224 L154 175.5 Q154 167.5 162 167.5 L186 167.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-f6a65e5ef8c2bcff-rr-return)" data-connector-id="c10:item-1/e.1:return" data-connector-source="" data-connector-target="" data-connector-route="M414 167.5 L438 167.5 Q446 167.5 446 175.5 L446 224 Q446 232 438 232 L162 232 Q154 232 154 224 L154 175.5 Q154 167.5 162 167.5 L186 167.5" data-connector-key="5"/>
  #|    <path class="rr-connector rr-gap" data-connector="c14:item-1/e.1.0.1:gap" data-role="gap" data-owner="item-1/e.1.0.1" d="M342 167.5 L362 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-1/e.1.0.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M342 167.5 L362 167.5" data-connector-key="6"/>
  #|    <path class="rr-connector rr-split-0" data-connector="c14:item-1/e.1.0.0:split-0" data-role="split-0" data-owner="item-1/e.1.0.0" d="M186 167.5 L250 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-1/e.1.0.0:split-0" data-connector-source="" data-connector-target="" data-connector-route="M186 167.5 L250 167.5" data-connector-key="7"/>
  #|    <path class="rr-connector rr-join-0" data-connector="c14:item-1/e.1.0.0:join-0" data-role="join-0" data-owner="item-1/e.1.0.0" d="M278 167.5 L342 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-1/e.1.0.0:join-0" data-connector-source="" data-connector-target="" data-connector-route="M278 167.5 L342 167.5" data-connector-key="8"/>
  #|    <path class="rr-connector rr-split-1" data-connector="c14:item-1/e.1.0.0:split-1" data-role="split-1" data-owner="item-1/e.1.0.0" d="M186 167.5 L210 167.5 Q218 167.5 218 175.5 L218 198.5 Q218 206.5 226 206.5 L250 206.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-1/e.1.0.0:split-1" data-connector-source="" data-connector-target="" data-connector-route="M186 167.5 L210 167.5 Q218 167.5 218 175.5 L218 198.5 Q218 206.5 226 206.5 L250 206.5" data-connector-key="9"/>
  #|    <path class="rr-connector rr-join-1" data-connector="c14:item-1/e.1.0.0:join-1" data-role="join-1" data-owner="item-1/e.1.0.0" d="M278 206.5 L302 206.5 Q310 206.5 310 198.5 L310 175.5 Q310 167.5 318 167.5 L342 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-1/e.1.0.0:join-1" data-connector-source="" data-connector-target="" data-connector-route="M278 206.5 L302 206.5 Q310 206.5 310 198.5 L310 175.5 Q310 167.5 318 167.5 L342 167.5" data-connector-key="10"/>
  #|    <path class="rr-connector rr-end" data-connector="c6:item-1:end" data-role="end" data-owner="item-1" d="M478 167.5 L498 167.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-1:end" data-connector-source="" data-connector-target="" data-connector-route="M478 167.5 L498 167.5" data-connector-key="11"/>
  #|    <path class="rr-connector rr-start" data-connector="c6:item-2:start" data-role="start" data-owner="item-2" d="M30 305.5 L50 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-2:start" data-connector-source="" data-connector-target="" data-connector-route="M30 305.5 L50 305.5" data-connector-key="12"/>
  #|    <path class="rr-connector rr-gap" data-connector="c10:item-2/e.1:gap" data-role="gap" data-owner="item-2/e.1" d="M118 305.5 L138 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-2/e.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M118 305.5 L138 305.5" data-connector-key="13"/>
  #|    <path class="rr-connector rr-enter" data-connector="c10:item-2/e.1:enter" data-role="enter" data-owner="item-2/e.1" d="M138 305.5 L202 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-2/e.1:enter" data-connector-source="" data-connector-target="" data-connector-route="M138 305.5 L202 305.5" data-connector-key="14"/>
  #|    <path class="rr-connector rr-leave" data-connector="c10:item-2/e.1:leave" data-role="leave" data-owner="item-2/e.1" d="M446 305.5 L510 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-2/e.1:leave" data-connector-source="" data-connector-target="" data-connector-route="M446 305.5 L510 305.5" data-connector-key="15"/>
  #|    <path class="rr-connector rr-bypass" data-connector="c10:item-2/e.1:bypass" data-role="bypass" data-owner="item-2/e.1" d="M138 305.5 L162 305.5 Q170 305.5 170 297.5 L170 288 Q170 280 178 280 L470 280 Q478 280 478 288 L478 297.5 Q478 305.5 486 305.5 L510 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-2/e.1:bypass" data-connector-source="" data-connector-target="" data-connector-route="M138 305.5 L162 305.5 Q170 305.5 170 297.5 L170 288 Q170 280 178 280 L470 280 Q478 280 478 288 L478 297.5 Q478 305.5 486 305.5 L510 305.5" data-connector-key="16"/>
  #|    <path class="rr-connector rr-return" data-connector="c10:item-2/e.1:return" data-role="return" data-owner="item-2/e.1" d="M446 305.5 L470 305.5 Q478 305.5 478 313.5 L478 362 Q478 370 470 370 L178 370 Q170 370 170 362 L170 313.5 Q170 305.5 178 305.5 L202 305.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-f6a65e5ef8c2bcff-rr-return)" data-connector-id="c10:item-2/e.1:return" data-connector-source="" data-connector-target="" data-connector-route="M446 305.5 L470 305.5 Q478 305.5 478 313.5 L478 362 Q478 370 470 370 L178 370 Q170 370 170 362 L170 313.5 Q170 305.5 178 305.5 L202 305.5" data-connector-key="17"/>
  #|    <path class="rr-connector rr-gap" data-connector="c14:item-2/e.1.0.1:gap" data-role="gap" data-owner="item-2/e.1.0.1" d="M358 305.5 L378 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-2/e.1.0.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M358 305.5 L378 305.5" data-connector-key="18"/>
  #|    <path class="rr-connector rr-split-0" data-connector="c14:item-2/e.1.0.0:split-0" data-role="split-0" data-owner="item-2/e.1.0.0" d="M202 305.5 L266 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-2/e.1.0.0:split-0" data-connector-source="" data-connector-target="" data-connector-route="M202 305.5 L266 305.5" data-connector-key="19"/>
  #|    <path class="rr-connector rr-join-0" data-connector="c14:item-2/e.1.0.0:join-0" data-role="join-0" data-owner="item-2/e.1.0.0" d="M294 305.5 L358 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-2/e.1.0.0:join-0" data-connector-source="" data-connector-target="" data-connector-route="M294 305.5 L358 305.5" data-connector-key="20"/>
  #|    <path class="rr-connector rr-split-1" data-connector="c14:item-2/e.1.0.0:split-1" data-role="split-1" data-owner="item-2/e.1.0.0" d="M202 305.5 L226 305.5 Q234 305.5 234 313.5 L234 336.5 Q234 344.5 242 344.5 L266 344.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-2/e.1.0.0:split-1" data-connector-source="" data-connector-target="" data-connector-route="M202 305.5 L226 305.5 Q234 305.5 234 313.5 L234 336.5 Q234 344.5 242 344.5 L266 344.5" data-connector-key="21"/>
  #|    <path class="rr-connector rr-join-1" data-connector="c14:item-2/e.1.0.0:join-1" data-role="join-1" data-owner="item-2/e.1.0.0" d="M294 344.5 L318 344.5 Q326 344.5 326 336.5 L326 313.5 Q326 305.5 334 305.5 L358 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c14:item-2/e.1.0.0:join-1" data-connector-source="" data-connector-target="" data-connector-route="M294 344.5 L318 344.5 Q326 344.5 326 336.5 L326 313.5 Q326 305.5 334 305.5 L358 305.5" data-connector-key="22"/>
  #|    <path class="rr-connector rr-end" data-connector="c6:item-2:end" data-role="end" data-owner="item-2" d="M510 305.5 L530 305.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-2:end" data-connector-source="" data-connector-target="" data-connector-route="M510 305.5 L530 305.5" data-connector-key="23"/>
  #|    <path class="rr-connector rr-start" data-connector="c6:item-3:start" data-role="start" data-owner="item-3" d="M30 431.5 L50 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-3:start" data-connector-source="" data-connector-target="" data-connector-route="M30 431.5 L50 431.5" data-connector-key="24"/>
  #|    <path class="rr-connector rr-split-0" data-connector="c8:item-3/e:split-0" data-role="split-0" data-owner="item-3/e" d="M50 431.5 L114 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:split-0" data-connector-source="" data-connector-target="" data-connector-route="M50 431.5 L114 431.5" data-connector-key="25"/>
  #|    <path class="rr-connector rr-join-0" data-connector="c8:item-3/e:join-0" data-role="join-0" data-owner="item-3/e" d="M182 431.5 L374 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:join-0" data-connector-source="" data-connector-target="" data-connector-route="M182 431.5 L374 431.5" data-connector-key="26"/>
  #|    <path class="rr-connector rr-split-1" data-connector="c8:item-3/e:split-1" data-role="split-1" data-owner="item-3/e" d="M50 431.5 L74 431.5 Q82 431.5 82 439.5 L82 462.5 Q82 470.5 90 470.5 L114 470.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:split-1" data-connector-source="" data-connector-target="" data-connector-route="M50 431.5 L74 431.5 Q82 431.5 82 439.5 L82 462.5 Q82 470.5 90 470.5 L114 470.5" data-connector-key="27"/>
  #|    <path class="rr-connector rr-join-1" data-connector="c8:item-3/e:join-1" data-role="join-1" data-owner="item-3/e" d="M310 470.5 L334 470.5 Q342 470.5 342 462.5 L342 439.5 Q342 431.5 350 431.5 L374 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:join-1" data-connector-source="" data-connector-target="" data-connector-route="M310 470.5 L334 470.5 Q342 470.5 342 462.5 L342 439.5 Q342 431.5 350 431.5 L374 431.5" data-connector-key="28"/>
  #|    <path class="rr-connector rr-split-2" data-connector="c8:item-3/e:split-2" data-role="split-2" data-owner="item-3/e" d="M50 431.5 L74 431.5 Q82 431.5 82 439.5 L82 501.5 Q82 509.5 90 509.5 L114 509.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:split-2" data-connector-source="" data-connector-target="" data-connector-route="M50 431.5 L74 431.5 Q82 431.5 82 439.5 L82 501.5 Q82 509.5 90 509.5 L114 509.5" data-connector-key="29"/>
  #|    <path class="rr-connector rr-join-2" data-connector="c8:item-3/e:join-2" data-role="join-2" data-owner="item-3/e" d="M230 509.5 L334 509.5 Q342 509.5 342 501.5 L342 439.5 Q342 431.5 350 431.5 L374 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c8:item-3/e:join-2" data-connector-source="" data-connector-target="" data-connector-route="M230 509.5 L334 509.5 Q342 509.5 342 501.5 L342 439.5 Q342 431.5 350 431.5 L374 431.5" data-connector-key="30"/>
  #|    <path class="rr-connector rr-gap" data-connector="c12:item-3/e.1.1:gap" data-role="gap" data-owner="item-3/e.1.1" d="M142 470.5 L162 470.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c12:item-3/e.1.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M142 470.5 L162 470.5" data-connector-key="31"/>
  #|    <path class="rr-connector rr-gap" data-connector="c12:item-3/e.1.2:gap" data-role="gap" data-owner="item-3/e.1.2" d="M262 470.5 L282 470.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c12:item-3/e.1.2:gap" data-connector-source="" data-connector-target="" data-connector-route="M262 470.5 L282 470.5" data-connector-key="32"/>
  #|    <path class="rr-connector rr-gap" data-connector="c12:item-3/e.2.1:gap" data-role="gap" data-owner="item-3/e.2.1" d="M142 509.5 L162 509.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c12:item-3/e.2.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M142 509.5 L162 509.5" data-connector-key="33"/>
  #|    <path class="rr-connector rr-end" data-connector="c6:item-3:end" data-role="end" data-owner="item-3" d="M374 431.5 L394 431.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-3:end" data-connector-source="" data-connector-target="" data-connector-route="M374 431.5 L394 431.5" data-connector-key="34"/>
  #|    <path class="rr-connector rr-start" data-connector="c6:item-4:start" data-role="start" data-owner="item-4" d="M30 596.5 L50 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-4:start" data-connector-source="" data-connector-target="" data-connector-route="M30 596.5 L50 596.5" data-connector-key="35"/>
  #|    <path class="rr-connector rr-gap" data-connector="c10:item-4/e.1:gap" data-role="gap" data-owner="item-4/e.1" d="M110 596.5 L130 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-4/e.1:gap" data-connector-source="" data-connector-target="" data-connector-route="M110 596.5 L130 596.5" data-connector-key="36"/>
  #|    <path class="rr-connector rr-enter" data-connector="c10:item-4/e.1:enter" data-role="enter" data-owner="item-4/e.1" d="M130 596.5 L194 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-4/e.1:enter" data-connector-source="" data-connector-target="" data-connector-route="M130 596.5 L194 596.5" data-connector-key="37"/>
  #|    <path class="rr-connector rr-leave" data-connector="c10:item-4/e.1:leave" data-role="leave" data-owner="item-4/e.1" d="M254 596.5 L318 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-4/e.1:leave" data-connector-source="" data-connector-target="" data-connector-route="M254 596.5 L318 596.5" data-connector-key="38"/>
  #|    <path class="rr-connector rr-bypass" data-connector="c10:item-4/e.1:bypass" data-role="bypass" data-owner="item-4/e.1" d="M130 596.5 L154 596.5 Q162 596.5 162 588.5 L162 579 Q162 571 170 571 L278 571 Q286 571 286 579 L286 588.5 Q286 596.5 294 596.5 L318 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c10:item-4/e.1:bypass" data-connector-source="" data-connector-target="" data-connector-route="M130 596.5 L154 596.5 Q162 596.5 162 588.5 L162 579 Q162 571 170 571 L278 571 Q286 571 286 579 L286 588.5 Q286 596.5 294 596.5 L318 596.5" data-connector-key="39"/>
  #|    <path class="rr-connector rr-return" data-connector="c10:item-4/e.1:return" data-role="return" data-owner="item-4/e.1" d="M254 596.5 L278 596.5 Q286 596.5 286 604.5 L286 614 Q286 622 278 622 L170 622 Q162 622 162 614 L162 604.5 Q162 596.5 170 596.5 L194 596.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#rr-f6a65e5ef8c2bcff-rr-return)" data-connector-id="c10:item-4/e.1:return" data-connector-source="" data-connector-target="" data-connector-route="M254 596.5 L278 596.5 Q286 596.5 286 604.5 L286 614 Q286 622 278 622 L170 622 Q162 622 162 614 L162 604.5 Q162 596.5 170 596.5 L194 596.5" data-connector-key="40"/>
  #|    <path class="rr-connector rr-end" data-connector="c6:item-4:end" data-role="end" data-owner="item-4" d="M318 596.5 L338 596.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-4:end" data-connector-source="" data-connector-target="" data-connector-route="M318 596.5 L338 596.5" data-connector-key="41"/>
  #|    <path class="rr-connector rr-start" data-connector="c6:item-5:start" data-role="start" data-owner="item-5" d="M30 683.5 L50 683.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-5:start" data-connector-source="" data-connector-target="" data-connector-route="M30 683.5 L50 683.5" data-connector-key="42"/>
  #|    <path class="rr-connector rr-split-0" data-connector="c12:item-5/e.1.0:split-0" data-role="split-0" data-owner="item-5/e.1.0" d="M64 751.5 L128 751.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c12:item-5/e.1.0:split-0" data-connector-source="" data-connector-target="" data-connector-route="M64 751.5 L128 751.5" data-connector-key="43"/>
  #|    <path class="rr-connector rr-join-0" data-connector="c12:item-5/e.1.0:join-0" data-role="join-0" data-owner="item-5/e.1.0" d="M156 751.5 L220 751.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c12:item-5/e.1.0:join-0" data-connector-source="" data-connector-target="" data-connector-route="M156 751.5 L220 751.5" data-connector-key="44"/>
  #|    <path class="rr-connector rr-split-1" data-connector="c12:item-5/e.1.0:split-1" data-role="split-1" data-owner="item-5/e.1.0" d="M64 751.5 L88 751.5 Q96 751.5 96 759.5 L96 782.5 Q96 790.5 104 790.5 L128 790.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c12:item-5/e.1.0:split-1" data-connector-source="" data-connector-target="" data-connector-route="M64 751.5 L88 751.5 Q96 751.5 96 759.5 L96 782.5 Q96 790.5 104 790.5 L128 790.5" data-connector-key="45"/>
  #|    <path class="rr-connector rr-join-1" data-connector="c12:item-5/e.1.0:join-1" data-role="join-1" data-owner="item-5/e.1.0" d="M156 790.5 L180 790.5 Q188 790.5 188 782.5 L188 759.5 Q188 751.5 196 751.5 L220 751.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c12:item-5/e.1.0:join-1" data-connector-source="" data-connector-target="" data-connector-route="M156 790.5 L180 790.5 Q188 790.5 188 782.5 L188 759.5 Q188 751.5 196 751.5 L220 751.5" data-connector-key="46"/>
  #|    <path class="rr-connector rr-enter" data-connector="c10:item-5/e.1:enter" data-role="enter" data-owner="item-5/e.1" d="M54 751.5 L64 751.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c10:item-5/e.1:enter" data-connector-source="" data-connector-target="" data-connector-route="M54 751.5 L64 751.5" data-connector-key="47"/>
  #|    <path class="rr-connector rr-leave" data-connector="c10:item-5/e.1:leave" data-role="leave" data-owner="item-5/e.1" d="M220 751.5 L230 751.5" fill="none" stroke="#5b6474" stroke-width="1.5" data-constraint="true" stroke-dasharray="4 3" data-connector-id="c10:item-5/e.1:leave" data-connector-source="" data-connector-target="" data-connector-route="M220 751.5 L230 751.5" data-connector-key="48"/>
  #|    <path class="rr-connector rr-end" data-connector="c6:item-5:end" data-role="end" data-owner="item-5" d="M222 683.5 L254 683.5" fill="none" stroke="#64748b" stroke-width="1.5" data-connector-id="c6:item-5:end" data-connector-source="" data-connector-target="" data-connector-route="M222 683.5 L254 683.5" data-connector-key="49"/>
  #|  </g>
  #|  <g class="rr-terms">
  #|    <g class="rr-term rr-reference" data-term="item-1/e.0" data-role="reference" data-rule="item-1" data-target="item-2">
  #|      <rect class="rr-box" x="50" y="154" width="52" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="76" y="170" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="76" y="170">term</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-1/e.1.0.0.0" data-role="consumed" data-rule="item-1">
  #|      <rect class="rr-box" x="250" y="154" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="264" y="170" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="264" y="170">+</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-1/e.1.0.0.1" data-role="consumed" data-rule="item-1">
  #|      <rect class="rr-box" x="250" y="193" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="264" y="209" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="264" y="209">-</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-1/e.1.0.1" data-role="reference" data-rule="item-1" data-target="item-2">
  #|      <rect class="rr-box" x="362" y="154" width="52" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="388" y="170" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="388" y="170">term</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-2/e.0" data-role="reference" data-rule="item-2" data-target="item-3">
  #|      <rect class="rr-box" x="50" y="292" width="68" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="84" y="308" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="84" y="308">factor</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-2/e.1.0.0.0" data-role="consumed" data-rule="item-2">
  #|      <rect class="rr-box" x="266" y="292" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="280" y="308" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="280" y="308">*</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-2/e.1.0.0.1" data-role="consumed" data-rule="item-2">
  #|      <rect class="rr-box" x="266" y="331" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="280" y="347" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="280" y="347">/</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-2/e.1.0.1" data-role="reference" data-rule="item-2" data-target="item-3">
  #|      <rect class="rr-box" x="378" y="292" width="68" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="412" y="308" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="412" y="308">factor</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-3/e.0" data-role="reference" data-rule="item-3" data-target="item-4">
  #|      <rect class="rr-box" x="114" y="418" width="68" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="148" y="434" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="148" y="434">number</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-3/e.1.0" data-role="consumed" data-rule="item-3">
  #|      <rect class="rr-box" x="114" y="457" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="128" y="473" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="128" y="473">(</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-3/e.1.1" data-role="reference" data-rule="item-3" data-target="item-1">
  #|      <rect class="rr-box" x="162" y="457" width="100" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="212" y="473" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="212" y="473">expression</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-3/e.1.2" data-role="consumed" data-rule="item-3">
  #|      <rect class="rr-box" x="282" y="457" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="296" y="473" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="296" y="473">)</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-3/e.2.0" data-role="consumed" data-rule="item-3">
  #|      <rect class="rr-box" x="114" y="496" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="128" y="512" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="128" y="512">-</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-3/e.2.1" data-role="reference" data-rule="item-3" data-target="item-3">
  #|      <rect class="rr-box" x="162" y="496" width="68" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="196" y="512" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="196" y="512">factor</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-4/e.0" data-role="reference" data-rule="item-4" data-target="item-5">
  #|      <rect class="rr-box" x="50" y="583" width="60" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="80" y="599" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="80" y="599">digit</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-reference" data-term="item-4/e.1.0" data-role="reference" data-rule="item-4" data-target="item-5">
  #|      <rect class="rr-box" x="194" y="583" width="60" height="27" rx="2" fill="rgba(167, 139, 250, 0.2)" stroke="#7c3aed" stroke-width="1.5"/>
  #|      <text class="rr-label" x="224" y="599" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="600" fill="#111827">
  #|        <tspan x="224" y="599">digit</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-special" data-term="item-5/e.0" data-role="consumed" data-rule="item-5">
  #|      <rect class="rr-box" x="50" y="670" width="172" height="27" rx="6" fill="rgba(251, 146, 60, 0.15)" stroke="#ea580c" stroke-width="1.5" stroke-dasharray="2 3"/>
  #|      <text class="rr-label" x="136" y="686" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="136" y="686"> any decimal digit </tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-5/e.1.0.0" data-role="consumed" data-rule="item-5" data-constraint="true">
  #|      <rect class="rr-box" x="128" y="738" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="142" y="754" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="142" y="754">0</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="rr-term rr-terminal" data-term="item-5/e.1.0.1" data-role="consumed" data-rule="item-5" data-constraint="true">
  #|      <rect class="rr-box" x="128" y="777" width="28" height="27" rx="13.5" fill="rgba(34, 211, 238, 0.15)" stroke="#0891b2" stroke-width="1.5"/>
  #|      <text class="rr-label" x="142" y="793" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="142" y="793">0</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="rr-tracks">
  #|    <g class="rr-track" data-rule="item-1">
  #|      <text class="rr-rule-name" x="20" y="130" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="130">expression</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="167.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="504" cy="167.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="504" cy="167.5" r="3" fill="#64748b"/>
  #|    </g>
  #|    <g class="rr-track" data-rule="item-2">
  #|      <text class="rr-rule-name" x="20" y="268" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="268">term</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="305.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="536" cy="305.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="536" cy="305.5" r="3" fill="#64748b"/>
  #|    </g>
  #|    <g class="rr-track" data-rule="item-3">
  #|      <text class="rr-rule-name" x="20" y="406" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="406">factor</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="431.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="400" cy="431.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="400" cy="431.5" r="3" fill="#64748b"/>
  #|    </g>
  #|    <g class="rr-track" data-rule="item-4">
  #|      <text class="rr-rule-name" x="20" y="559" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="559">number</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="596.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="344" cy="596.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="344" cy="596.5" r="3" fill="#64748b"/>
  #|    </g>
  #|    <g class="rr-track" data-rule="item-5">
  #|      <text class="rr-rule-name" x="20" y="658" text-anchor="start" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="14" font-weight="700" fill="#111827">
  #|        <tspan x="20" y="658">digit</tspan>
  #|      </text>
  #|      <circle class="rr-start" cx="25" cy="683.5" r="5" fill="#64748b"/>
  #|      <circle class="rr-end" cx="260" cy="683.5" r="6" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|      <circle cx="260" cy="683.5" r="3" fill="#64748b"/>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_8 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 896 332" width="896" height="332" role="img" data-diagram="data-tree" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="dt-b14ea749b6015f27-diagram">
  #|  <title>Order with nested collections</title>
  #|  <desc>Structured data diagram with 17 values in 7 containers. Rows show members in source order and arrays show positions; connectors join nested containers.</desc>
  #|  <defs>
  #|    <marker id="dt-b14ea749b6015f27-dt-arrow" viewBox="-10 -6 12 12" refX="0" refY="0" markerWidth="12" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#64748b"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="896" height="332" fill="#f4f5f7"/>
  #|  <text class="data-title" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="16" font-weight="700" fill="#111827">
  #|    <tspan x="20" y="34" xml:space="preserve">Order with nested collections</tspan>
  #|  </text>
  #|  <g class="data-connectors">
  #|    <path class="data-connector" data-member="m/3" data-source="v" data-target="v/3" d="M428 147.5 C460 147.5 460 147.5 468 147.5 L492 147.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/3" data-connector-source="v" data-connector-target="v/3" data-connector-route="M428 147.5 C460 147.5 460 147.5 492 147.5" data-connector-key="0"/>
  #|    <path class="data-connector" data-member="m/5" data-source="v" data-target="v/5" d="M428 218.5 C460 218.5 460 218.5 468 218.5 L492 218.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/5" data-connector-source="v" data-connector-target="v/5" data-connector-route="M428 218.5 C460 218.5 460 218.5 492 218.5" data-connector-key="1"/>
  #|    <path class="data-connector" data-member="m/3/0" data-source="v/3" data-target="v/3/0" d="M572 147.5 C604 147.5 604 147.5 612 147.5 L636 147.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/3/0" data-connector-source="v/3" data-connector-target="v/3/0" data-connector-route="M572 147.5 C604 147.5 604 147.5 636 147.5" data-connector-key="2"/>
  #|    <path class="data-connector" data-member="m/3/1" data-source="v/3" data-target="v/3/1" d="M572 174.5 C604 174.5 604 244.5 612 244.5 L636 244.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/3/1" data-connector-source="v/3" data-connector-target="v/3/1" data-connector-route="M572 174.5 C604 174.5 604 244.5 636 244.5" data-connector-key="3"/>
  #|    <path class="data-connector" data-member="m/3/0/2" data-source="v/3/0" data-target="v/3/0/2" d="M724 201.5 C756 201.5 756 201.5 764 201.5 L788 201.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/3/0/2" data-connector-source="v/3/0" data-connector-target="v/3/0/2" data-connector-route="M724 201.5 C756 201.5 756 201.5 788 201.5" data-connector-key="4"/>
  #|    <path class="data-connector" data-member="m/3/1/2" data-source="v/3/1" data-target="v/3/1/2" d="M724 298.5 C756 298.5 756 298.5 764 298.5 L788 298.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-b14ea749b6015f27-dt-arrow)" data-connector-id="m/3/1/2" data-connector-source="v/3/1" data-connector-target="v/3/1/2" data-connector-route="M724 298.5 C756 298.5 756 298.5 788 298.5" data-connector-key="5"/>
  #|  </g>
  #|  <g class="data-boxes">
  #|    <g class="data-box" data-node="v" data-type="object">
  #|      <rect class="data-box-frame" x="20" y="53" width="408" height="179" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/0" data-node="v/0" data-type="number">
  #|        <rect class="data-row-bounds" x="20" y="53" width="408" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="69" xml:space="preserve">id</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#077995">
  #|          <tspan x="92" y="69" xml:space="preserve">12345678901234567890</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/1" data-node="v/1" data-type="boolean">
  #|        <rect class="data-row-bounds" x="20" y="80" width="408" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="96" xml:space="preserve">paid</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#7c3aed">
  #|          <tspan x="92" y="96" xml:space="preserve">☑ true</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/2" data-node="v/2" data-type="null">
  #|        <rect class="data-row-bounds" x="20" y="107" width="408" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="123" xml:space="preserve">coupon</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="92" y="123" xml:space="preserve">␀ null</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3" data-node="v/3" data-type="array">
  #|        <rect class="data-row-bounds" x="20" y="134" width="408" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="150" xml:space="preserve">items</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="92" y="150" xml:space="preserve">[…]</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/4" data-node="v/4" data-type="string">
  #|        <rect class="data-row-bounds" x="20" y="161" width="408" height="44" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="177" xml:space="preserve">notes</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="92" y="177" xml:space="preserve">A long note wraps inside its row without </tspan>
  #|          <tspan x="92" y="194" xml:space="preserve">losing any character of the value text</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/5" data-node="v/5" data-type="object">
  #|        <rect class="data-row-bounds" x="20" y="205" width="408" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="221" xml:space="preserve">meta</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="92" y="221" xml:space="preserve">{}</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M84 53 V232" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/3" data-type="array">
  #|      <rect class="data-box-frame" x="492" y="134" width="80" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/3/0" data-node="v/3/0" data-type="object">
  #|        <rect class="data-row-bounds" x="492" y="134" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="500" y="150" xml:space="preserve">[0]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="540" y="150" xml:space="preserve">{…}</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/1" data-node="v/3/1" data-type="object">
  #|        <rect class="data-row-bounds" x="492" y="161" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="500" y="177" xml:space="preserve">[1]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="540" y="177" xml:space="preserve">{…}</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M532 134 V188" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/3/0" data-type="object">
  #|      <rect class="data-box-frame" x="636" y="134" width="88" height="81" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/3/0/0" data-node="v/3/0/0" data-type="string" data-highlight="true">
  #|        <rect class="data-row-bounds" x="636" y="134" width="88" height="27" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="150" xml:space="preserve">sku</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="692" y="150" xml:space="preserve">A-1</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/0/1" data-node="v/3/0/1" data-type="number">
  #|        <rect class="data-row-bounds" x="636" y="161" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="177" xml:space="preserve">qty</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#077995">
  #|          <tspan x="692" y="177" xml:space="preserve">2</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/0/2" data-node="v/3/0/2" data-type="array">
  #|        <rect class="data-row-bounds" x="636" y="188" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="204" xml:space="preserve">tags</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="692" y="204" xml:space="preserve">[…]</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M684 134 V215" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/3/0/2" data-type="array">
  #|      <rect class="data-box-frame" x="788" y="188" width="88" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/3/0/2/0" data-node="v/3/0/2/0" data-type="string">
  #|        <rect class="data-row-bounds" x="788" y="188" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="796" y="204" xml:space="preserve">[0]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="836" y="204" xml:space="preserve">gift</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/0/2/1" data-node="v/3/0/2/1" data-type="string">
  #|        <rect class="data-row-bounds" x="788" y="215" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="796" y="231" xml:space="preserve">[1]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="836" y="231" xml:space="preserve">gift</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M828 188 V242" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/3/1" data-type="object">
  #|      <rect class="data-box-frame" x="636" y="231" width="88" height="81" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/3/1/0" data-node="v/3/1/0" data-type="string">
  #|        <rect class="data-row-bounds" x="636" y="231" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="247" xml:space="preserve">sku</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="692" y="247" xml:space="preserve">B-2</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/1/1" data-node="v/3/1/1" data-type="number">
  #|        <rect class="data-row-bounds" x="636" y="258" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="274" xml:space="preserve">qty</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#077995">
  #|          <tspan x="692" y="274" xml:space="preserve">1</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/3/1/2" data-node="v/3/1/2" data-type="array">
  #|        <rect class="data-row-bounds" x="636" y="285" width="88" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="644" y="301" xml:space="preserve">tags</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="692" y="301" xml:space="preserve">[]</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M684 231 V312" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/3/1/2" data-type="array" data-empty="true">
  #|      <rect class="data-box-frame" x="788" y="285" width="32" height="27" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|        <tspan x="796" y="301" xml:space="preserve">[]</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="data-box" data-node="v/5" data-type="object" data-empty="true">
  #|      <rect class="data-box-frame" x="492" y="205" width="32" height="27" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|        <tspan x="500" y="221" xml:space="preserve">{}</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_9 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 616 382" width="616" height="382" role="img" data-diagram="data-tree" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="dt-81da5b3b20439b69-diagram">
  #|  <title>Native YAML keeps scalars as text</title>
  #|  <desc>Structured data diagram with 16 values in 6 containers. Rows show members in source order and arrays show positions; connectors join nested containers.</desc>
  #|  <defs>
  #|    <marker id="dt-81da5b3b20439b69-dt-arrow" viewBox="-10 -6 12 12" refX="0" refY="0" markerWidth="12" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#64748b"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="616" height="382" fill="#f4f5f7"/>
  #|  <text class="data-title" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="16" font-weight="700" fill="#111827">
  #|    <tspan x="20" y="34" xml:space="preserve">Native YAML keeps scalars as text</tspan>
  #|  </text>
  #|  <g class="data-connectors">
  #|    <path class="data-connector" data-member="m/0" data-source="v" data-target="v/0" d="M132 66.5 C164 66.5 164 66.5 172 66.5 L196 66.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-81da5b3b20439b69-dt-arrow)" data-connector-id="m/0" data-connector-source="v" data-connector-target="v/0" data-connector-route="M132 66.5 C164 66.5 164 66.5 196 66.5" data-connector-key="0"/>
  #|    <path class="data-connector" data-member="m/1" data-source="v" data-target="v/1" d="M132 93.5 C164 93.5 164 251.5 172 251.5 L196 251.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-81da5b3b20439b69-dt-arrow)" data-connector-id="m/1" data-connector-source="v" data-connector-target="v/1" data-connector-route="M132 93.5 C164 93.5 164 251.5 196 251.5" data-connector-key="1"/>
  #|    <path class="data-connector" data-member="m/0/3" data-source="v/0" data-target="v/0/3" d="M404 147.5 C436 147.5 436 147.5 444 147.5 L468 147.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-81da5b3b20439b69-dt-arrow)" data-connector-id="m/0/3" data-connector-source="v/0" data-connector-target="v/0/3" data-connector-route="M404 147.5 C436 147.5 436 147.5 468 147.5" data-connector-key="2"/>
  #|    <path class="data-connector" data-member="m/1/0" data-source="v/1" data-target="v/1/0" d="M276 251.5 L404 251.5 C436 251.5 436 251.5 444 251.5 L468 251.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-81da5b3b20439b69-dt-arrow)" data-connector-id="m/1/0" data-connector-source="v/1" data-connector-target="v/1/0" data-connector-route="M276 251.5 H404 C436 251.5 436 251.5 468 251.5" data-connector-key="3"/>
  #|    <path class="data-connector" data-member="m/1/1" data-source="v/1" data-target="v/1/1" d="M276 278.5 L404 278.5 C436 278.5 436 321.5 444 321.5 L468 321.5" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#dt-81da5b3b20439b69-dt-arrow)" data-connector-id="m/1/1" data-connector-source="v/1" data-connector-target="v/1/1" data-connector-route="M276 278.5 H404 C436 278.5 436 321.5 468 321.5" data-connector-key="4"/>
  #|  </g>
  #|  <g class="data-boxes">
  #|    <g class="data-box" data-node="v" data-type="object">
  #|      <rect class="data-box-frame" x="20" y="53" width="112" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/0" data-node="v/0" data-type="object">
  #|        <rect class="data-row-bounds" x="20" y="53" width="112" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="69" xml:space="preserve">service</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="100" y="69" xml:space="preserve">{…}</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/1" data-node="v/1" data-type="array">
  #|        <rect class="data-row-bounds" x="20" y="80" width="112" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="28" y="96" xml:space="preserve">clients</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="100" y="96" xml:space="preserve">[…]</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M92 53 V107" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/0" data-type="object">
  #|      <rect class="data-box-frame" x="196" y="53" width="208" height="169" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/0/0" data-node="v/0/0" data-type="string">
  #|        <rect class="data-row-bounds" x="196" y="53" width="208" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="204" y="69" xml:space="preserve">name</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="308" y="69" xml:space="preserve">api</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/0/1" data-node="v/0/1" data-type="string">
  #|        <rect class="data-row-bounds" x="196" y="80" width="208" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="204" y="96" xml:space="preserve">enabled</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="308" y="96" xml:space="preserve">true</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/0/2" data-node="v/0/2" data-type="string">
  #|        <rect class="data-row-bounds" x="196" y="107" width="208" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="204" y="123" xml:space="preserve">replicas</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="308" y="123" xml:space="preserve">3</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/0/3" data-node="v/0/3" data-type="array" data-highlight="true">
  #|        <rect class="data-row-bounds" x="196" y="134" width="208" height="27" fill="rgba(251, 191, 36, 0.18)" stroke="#d97706" stroke-width="1.5"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="204" y="150" xml:space="preserve">ports</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="308" y="150" xml:space="preserve">[…]</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/0/4" data-node="v/0/4" data-type="string">
  #|        <rect class="data-row-bounds" x="196" y="161" width="208" height="61" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="204" y="177" xml:space="preserve">description</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="308" y="177" xml:space="preserve">First line</tspan>
  #|          <tspan x="308" y="194" xml:space="preserve">Second line</tspan>
  #|          <tspan x="308" y="211" xml:space="preserve"></tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M300 53 V222" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/0/3" data-type="array">
  #|      <rect class="data-box-frame" x="468" y="134" width="80" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/0/3/0" data-node="v/0/3/0" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="134" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="476" y="150" xml:space="preserve">[0]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="516" y="150" xml:space="preserve">80</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/0/3/1" data-node="v/0/3/1" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="161" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="476" y="177" xml:space="preserve">[1]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="516" y="177" xml:space="preserve">443</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M508 134 V188" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/1" data-type="array">
  #|      <rect class="data-box-frame" x="196" y="238" width="80" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/1/0" data-node="v/1/0" data-type="object">
  #|        <rect class="data-row-bounds" x="196" y="238" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="204" y="254" xml:space="preserve">[0]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="244" y="254" xml:space="preserve">{…}</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/1/1" data-node="v/1/1" data-type="object">
  #|        <rect class="data-row-bounds" x="196" y="265" width="80" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="204" y="281" xml:space="preserve">[1]</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#5b6474">
  #|          <tspan x="244" y="281" xml:space="preserve">{…}</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M236 238 V292" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/1/0" data-type="object">
  #|      <rect class="data-box-frame" x="468" y="238" width="104" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/1/0/0" data-node="v/1/0/0" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="238" width="104" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="476" y="254" xml:space="preserve">name</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="540" y="254" xml:space="preserve">web</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/1/0/1" data-node="v/1/0/1" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="265" width="104" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="476" y="281" xml:space="preserve">weight</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="540" y="281" xml:space="preserve">0.5</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M532 238 V292" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|    <g class="data-box" data-node="v/1/1" data-type="object">
  #|      <rect class="data-box-frame" x="468" y="308" width="128" height="54" rx="4" fill="#ffffff" stroke="#64748b" stroke-width="1.5"/>
  #|      <g class="data-row" data-member="m/1/1/0" data-node="v/1/1/0" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="308" width="128" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="476" y="324" xml:space="preserve">name</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="540" y="324" xml:space="preserve">mobile</tspan>
  #|        </text>
  #|      </g>
  #|      <g class="data-row" data-member="m/1/1/1" data-node="v/1/1/1" data-type="string">
  #|        <rect class="data-row-bounds" x="468" y="335" width="128" height="27" fill="#ffffff" stroke="#64748b" stroke-width="0.75"/>
  #|        <text class="data-key" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#111827">
  #|          <tspan x="476" y="351" xml:space="preserve">weight</tspan>
  #|        </text>
  #|        <text class="data-value" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047d58">
  #|          <tspan x="540" y="351" xml:space="preserve">0.5</tspan>
  #|        </text>
  #|      </g>
  #|      <path class="data-divider" d="M532 308 V362" fill="none" stroke="#64748b" stroke-width="0.75"/>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_10 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 946" width="300" height="946" role="img" data-diagram="state" data-connector-options="{&#xa;  style: Some(Rounded),&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-diagram">
  #|  <title>state-mermaid-lifecycle</title>
  #|  <desc>State structure and supplied scenarios. Guards, actions and history remain descriptive data.</desc>
  #|  <defs>
  #|    <marker id="sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-arrow" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-circle" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 0 A4 4 0 1 0 4 0 A4 4 0 1 0 -4 0 Z" fill="#64748b" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-cross" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 -4 L4 4 M-4 4 L4 -4" fill="none" stroke="#64748b" stroke-width="1.5"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="300" height="946" fill="#f4f5f7"/>
  #|  <g class="state-backgrounds">
  #|    <g class="state-group" data-state-id="root">
  #|      <rect class="state-bounds" x="0" y="0" width="300" height="946" fill="none" stroke="none"/>
  #|    </g>
  #|  </g>
  #|  <g class="state-connections">
  #|    <g class="state-connection" data-state-id="transition-0" data-source="root::initial" data-target="Idle" data-display-source="root::initial" data-display-target="Idle">
  #|      <path class="state-connector" d="M116 128 L116 152 Q116 160 124 160 L152 160 Q160 160 160 168 L160 353" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="transition-0" data-connector-source="root::initial" data-connector-target="Idle" data-connector-route="M116 128 L116 160 L160 160 L160 353" data-connector-key="0"/>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition-1" data-source="Idle" data-target="Running" data-display-source="Idle" data-display-target="Running">
  #|      <path class="state-connector" d="M160 417 L160 441 Q160 449 152 449 L120 449 Q112 449 112 457 L112 593.734" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="transition-1" data-connector-source="Idle" data-connector-target="Running" data-connector-route="M160 417 L160 449 L112 449 L112 593.734" data-connector-key="1"/>
  #|      <rect x="88" y="492.367" width="48" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="state-label" data-label-owner="transition-1" x="112" y="507.367" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="112" y="507.367">start</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition-2" data-source="Running" data-target="Running" data-display-source="Running" data-display-target="Running">
  #|      <path class="state-connector" d="M216 625 L240 625 Q248 625 248 617 L248 561.734 Q248 553.734 240 553.734 L216 553.734 Q208 553.734 208 561.734 L208 593.734" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="transition-2" data-connector-source="Running" data-connector-target="Running" data-connector-route="M216 625 L248 625 L248 553.734 L208 553.734 L208 593.734" data-connector-key="2"/>
  #|      <rect x="224" y="560.367" width="48" height="21" rx="3" fill="#f4f5f7"/>
  #|      <text class="state-label" data-label-owner="transition-2" x="248" y="575.367" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#111827">
  #|        <tspan x="248" y="575.367">retry</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition-3" data-source="Running" data-target="root::final" data-display-source="Running" data-display-target="root::final">
  #|      <path class="state-connector" d="M160 657 L160 681 Q160 689 152 689 L128 689 Q120 689 120 697 L120 833" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-6d-65-72-6d-61-69-64-2d-6c-69-66-65-63-79-63-6c-65-2d-6c-69-67-68-74-sl-arrow)" data-connector-id="transition-3" data-connector-source="Running" data-connector-target="root::final" data-connector-route="M160 657 L160 689 L120 689 L120 833" data-connector-key="3"/>
  #|    </g>
  #|  </g>
  #|  <g class="state-nodes">
  #|    <g class="state-node" data-state-id="root::initial" data-shape="f-circ" data-expanded="true" data-parent="root" data-role="Initial">
  #|      <rect class="state-bounds" x="104" y="104" width="24" height="73" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M128 116 L127.942 117.176 L127.769 118.341 L127.483 119.483 L127.087 120.592 L126.583 121.657 L125.978 122.667 L125.276 123.613 L124.485 124.485 L123.613 125.276 L122.667 125.978 L121.657 126.583 L120.592 127.087 L119.483 127.483 L118.341 127.769 L117.176 127.942 L116 128 L114.824 127.942 L113.659 127.769 L112.517 127.483 L111.408 127.087 L110.343 126.583 L109.333 125.978 L108.387 125.276 L107.515 124.485 L106.724 123.613 L106.022 122.667 L105.417 121.657 L104.913 120.592 L104.517 119.483 L104.231 118.341 L104.058 117.176 L104 116 L104.058 114.824 L104.231 113.659 L104.517 112.517 L104.913 111.408 L105.417 110.343 L106.022 109.333 L106.724 108.387 L107.515 107.515 L108.387 106.724 L109.333 106.022 L110.343 105.417 L111.408 104.913 L112.517 104.517 L113.659 104.231 L114.824 104.058 L116 104 L117.176 104.058 L118.341 104.231 L119.483 104.517 L120.592 104.913 L121.657 105.417 L122.667 106.022 L123.613 106.724 L124.485 107.515 L125.276 108.387 L125.978 109.333 L126.583 110.343 L127.087 111.408 L127.483 112.517 L127.769 113.659 L127.942 114.824 L128 116 Z" fill="#b44409" stroke="#ea580c" stroke-width="1.5"/>
  #|    </g>
  #|    <g class="state-node" data-state-id="Idle" data-shape="rounded" data-expanded="true" data-parent="root" data-role="Simple">
  #|      <rect class="state-bounds" x="104" y="353" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M204 353 L206.341 353.231 L208.592 353.913 L210.667 355.022 L212.485 356.515 L213.978 358.333 L215.087 360.408 L215.769 362.659 L216 365 L216 405 L215.769 407.341 L215.087 409.592 L213.978 411.667 L212.485 413.485 L210.667 414.978 L208.592 416.087 L206.341 416.769 L204 417 L116 417 L113.659 416.769 L111.408 416.087 L109.333 414.978 L107.515 413.485 L106.022 411.667 L104.913 409.592 L104.231 407.341 L104 405 L104 365 L104.231 362.659 L104.913 360.408 L106.022 358.333 L107.515 356.515 L109.333 355.022 L111.408 353.913 L113.659 353.231 L116 353 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Idle" x="160" y="389.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="160" y="389.5">Idle</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="Running" data-shape="rounded" data-expanded="true" data-parent="root" data-role="Simple">
  #|      <rect class="state-bounds" x="104" y="593" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M204 593 L206.341 593.231 L208.592 593.913 L210.667 595.022 L212.485 596.515 L213.978 598.333 L215.087 600.408 L215.769 602.659 L216 605 L216 645 L215.769 647.341 L215.087 649.592 L213.978 651.667 L212.485 653.485 L210.667 654.978 L208.592 656.087 L206.341 656.769 L204 657 L116 657 L113.659 656.769 L111.408 656.087 L109.333 654.978 L107.515 653.485 L106.022 651.667 L104.913 649.592 L104.231 647.341 L104 645 L104 605 L104.231 602.659 L104.913 600.408 L106.022 598.333 L107.515 596.515 L109.333 595.022 L111.408 593.913 L113.659 593.231 L116 593 Z" fill="rgba(52, 211, 153, 0.18)" stroke="#059669" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Running" x="160" y="629.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#047351">
  #|        <tspan x="160" y="629.5">Running</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="root::final" data-shape="fr-circ" data-expanded="true" data-parent="root" data-role="Final">
  #|      <rect class="state-bounds" x="104" y="833" width="32" height="81" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M136 849 L135.923 850.568 L135.693 852.121 L135.311 853.645 L134.782 855.123 L134.111 856.542 L133.304 857.889 L132.368 859.15 L131.314 860.314 L130.15 861.368 L128.889 862.304 L127.542 863.111 L126.123 863.782 L124.645 864.311 L123.121 864.693 L121.568 864.923 L120 865 L118.432 864.923 L116.879 864.693 L115.355 864.311 L113.877 863.782 L112.458 863.111 L111.111 862.304 L109.85 861.368 L108.686 860.314 L107.632 859.15 L106.696 857.889 L105.889 856.542 L105.218 855.123 L104.689 853.645 L104.307 852.121 L104.077 850.568 L104 849 L104.077 847.432 L104.307 845.879 L104.689 844.355 L105.218 842.877 L105.889 841.458 L106.696 840.111 L107.632 838.85 L108.686 837.686 L109.85 836.632 L111.111 835.696 L112.458 834.889 L113.877 834.218 L115.355 833.689 L116.879 833.307 L118.432 833.077 L120 833 L121.568 833.077 L123.121 833.307 L124.645 833.689 L126.123 834.218 L127.542 834.889 L128.889 835.696 L130.15 836.632 L131.314 837.686 L132.368 838.85 L133.304 840.111 L134.111 841.458 L134.782 842.877 L135.311 844.355 L135.693 845.879 L135.923 847.432 L136 849 Z" fill="rgba(251, 146, 60, 0.15)" stroke="#ea580c" stroke-width="1.5"/>
  #|      <ellipse cx="120" cy="849" rx="10" ry="10" fill="#b44409" stroke="#ea580c" stroke-width="1.5"/>
  #|    </g>
  #|  </g>
  #|</svg>

///|
let still_source_11 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 468 240" width="468" height="240" role="img" data-diagram="sequence" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="seq-cdd79757e6e96c42-diagram">
  #|  <title>Sequence diagram</title>
  #|  <desc>Sequence diagram with 3 participants (Client, U, API) and 2 messages.</desc>
  #|  <defs>
  #|    <style>
  #|svg#seq-cdd79757e6e96c42-diagram {
  #|  --bg: #020617;
  #|  --text: #ffffff;
  #|  --muted: #94a3b8;
  #|  --mask: #0f172a;
  #|  --arrow: #94a3b8;
  #|  --frontend-fill: rgba(8, 51, 68, 0.4);
  #|  --frontend-stroke: #22d3ee;
  #|  --frontend-ink: #22d3ee;
  #|  --backend-fill: rgba(6, 78, 59, 0.4);
  #|  --backend-stroke: #34d399;
  #|  --backend-ink: #34d399;
  #|  --database-fill: rgba(76, 29, 149, 0.4);
  #|  --database-stroke: #a78bfa;
  #|  --database-ink: #a78bfa;
  #|  --cloud-fill: rgba(120, 53, 15, 0.3);
  #|  --cloud-stroke: #fbbf24;
  #|  --cloud-ink: #fbbf24;
  #|  --security-fill: rgba(136, 19, 55, 0.4);
  #|  --security-stroke: #fb7185;
  #|  --security-ink: #fb7185;
  #|  --messagebus-fill: rgba(251, 146, 60, 0.3);
  #|  --messagebus-stroke: #fb923c;
  #|  --messagebus-ink: #fb923c;
  #|  --external-fill: rgba(30, 41, 59, 0.5);
  #|  --external-stroke: #94a3b8;
  #|  --external-ink: #94a3b8;
  #|}
  #|@media (prefers-color-scheme: light) {
  #|  svg#seq-cdd79757e6e96c42-diagram {
  #|    --bg: #f4f5f7;
  #|    --text: #111827;
  #|    --muted: #5b6474;
  #|    --mask: #ffffff;
  #|    --arrow: #64748b;
  #|    --frontend-fill: rgba(34, 211, 238, 0.15);
  #|    --frontend-stroke: #0891b2;
  #|    --frontend-ink: #077995;
  #|    --backend-fill: rgba(52, 211, 153, 0.18);
  #|    --backend-stroke: #059669;
  #|    --backend-ink: #047d58;
  #|    --database-fill: rgba(167, 139, 250, 0.2);
  #|    --database-stroke: #7c3aed;
  #|    --database-ink: #7c3aed;
  #|    --cloud-fill: rgba(251, 191, 36, 0.18);
  #|    --cloud-stroke: #d97706;
  #|    --cloud-ink: #a75c05;
  #|    --security-fill: rgba(251, 113, 133, 0.15);
  #|    --security-stroke: #e11d48;
  #|    --security-ink: #d81c45;
  #|    --messagebus-fill: rgba(251, 146, 60, 0.15);
  #|    --messagebus-stroke: #ea580c;
  #|    --messagebus-ink: #c3490a;
  #|    --external-fill: rgba(148, 163, 184, 0.18);
  #|    --external-stroke: #64748b;
  #|    --external-ink: #606f85;
  #|  }
  #|}
  #|svg#seq-cdd79757e6e96c42-diagram[data-theme="dark"] {
  #|  --bg: #020617;
  #|  --text: #ffffff;
  #|  --muted: #94a3b8;
  #|  --mask: #0f172a;
  #|  --arrow: #94a3b8;
  #|  --frontend-fill: rgba(8, 51, 68, 0.4);
  #|  --frontend-stroke: #22d3ee;
  #|  --frontend-ink: #22d3ee;
  #|  --backend-fill: rgba(6, 78, 59, 0.4);
  #|  --backend-stroke: #34d399;
  #|  --backend-ink: #34d399;
  #|  --database-fill: rgba(76, 29, 149, 0.4);
  #|  --database-stroke: #a78bfa;
  #|  --database-ink: #a78bfa;
  #|  --cloud-fill: rgba(120, 53, 15, 0.3);
  #|  --cloud-stroke: #fbbf24;
  #|  --cloud-ink: #fbbf24;
  #|  --security-fill: rgba(136, 19, 55, 0.4);
  #|  --security-stroke: #fb7185;
  #|  --security-ink: #fb7185;
  #|  --messagebus-fill: rgba(251, 146, 60, 0.3);
  #|  --messagebus-stroke: #fb923c;
  #|  --messagebus-ink: #fb923c;
  #|  --external-fill: rgba(30, 41, 59, 0.5);
  #|  --external-stroke: #94a3b8;
  #|  --external-ink: #94a3b8;
  #|}
  #|svg#seq-cdd79757e6e96c42-diagram[data-theme="light"] {
  #|  --bg: #f4f5f7;
  #|  --text: #111827;
  #|  --muted: #5b6474;
  #|  --mask: #ffffff;
  #|  --arrow: #64748b;
  #|  --frontend-fill: rgba(34, 211, 238, 0.15);
  #|  --frontend-stroke: #0891b2;
  #|  --frontend-ink: #077995;
  #|  --backend-fill: rgba(52, 211, 153, 0.18);
  #|  --backend-stroke: #059669;
  #|  --backend-ink: #047d58;
  #|  --database-fill: rgba(167, 139, 250, 0.2);
  #|  --database-stroke: #7c3aed;
  #|  --database-ink: #7c3aed;
  #|  --cloud-fill: rgba(251, 191, 36, 0.18);
  #|  --cloud-stroke: #d97706;
  #|  --cloud-ink: #a75c05;
  #|  --security-fill: rgba(251, 113, 133, 0.15);
  #|  --security-stroke: #e11d48;
  #|  --security-ink: #d81c45;
  #|  --messagebus-fill: rgba(251, 146, 60, 0.15);
  #|  --messagebus-stroke: #ea580c;
  #|  --messagebus-ink: #c3490a;
  #|  --external-fill: rgba(148, 163, 184, 0.18);
  #|  --external-stroke: #64748b;
  #|  --external-ink: #606f85;
  #|}
  #|</style>
  #|    <marker id="seq-cdd79757e6e96c42-head-0-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="var(--frontend-stroke)" stroke="var(--frontend-stroke)" stroke-width="1.4"/>
  #|    </marker>
  #|    <marker id="seq-cdd79757e6e96c42-head-1-end" viewBox="-10 -5 15 10" refX="0" refY="0" markerWidth="15" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9,-4 L0,0 L-9,4 z" fill="var(--frontend-stroke)" stroke="var(--frontend-stroke)" stroke-width="1.4"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="468" height="240" rx="0" fill="var(--bg)"/>
  #|  <g class="bands"/>
  #|  <g class="lifelines">
  #|    <path class="lifeline" d="M80 72 V208" fill="none" stroke="var(--arrow)" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M244 72 V208" fill="none" stroke="var(--arrow)" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|    <path class="lifeline" d="M388 72 V208" fill="none" stroke="var(--arrow)" stroke-width="0.8" stroke-dasharray="3 7"/>
  #|  </g>
  #|  <g class="activations"/>
  #|  <g class="messages">
  #|    <g class="message f-frontend" data-index="0" data-from="U" data-to="Client" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M237 127 L87 127" fill="none" stroke="var(--frontend-stroke)" stroke-width="1.4" marker-end="url(#seq-cdd79757e6e96c42-head-0-end)" data-connector-id="0" data-connector-source="U" data-connector-target="Client" data-connector-route="M237 127 L87 127" data-connector-key="0"/>
  #|      <rect class="mask" x="96" y="100" width="132" height="23" rx="3" fill="var(--mask)"/>
  #|      <text class="m-label" x="162" y="115" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="var(--frontend-ink)">
  #|        <tspan x="162" y="115">open the forecast</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="message f-frontend" data-index="1" data-from="Client" data-to="API" data-sender-head="none" data-receiver-head="arrow">
  #|      <path class="m-line" d="M87 175 L381 175" fill="none" stroke="var(--frontend-stroke)" stroke-width="1.4" marker-end="url(#seq-cdd79757e6e96c42-head-1-end)" data-connector-id="1" data-connector-source="Client" data-connector-target="API" data-connector-route="M87 175 L381 175" data-connector-key="1"/>
  #|      <rect class="mask" x="182" y="148" width="105" height="23" rx="3" fill="var(--mask)"/>
  #|      <text class="m-label" x="234" y="163" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="11" font-weight="400" fill="var(--frontend-ink)">
  #|        <tspan x="234" y="163">GET /forecast</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="notes"/>
  #|  <g class="participants">
  #|    <g class="participant f-frontend" data-id="Client">
  #|      <rect class="mask" x="32" y="24" width="96" height="48" rx="6" fill="var(--mask)"/>
  #|      <rect class="box" x="32" y="24" width="96" height="48" rx="6" fill="var(--frontend-fill)" stroke="var(--frontend-stroke)" stroke-width="1.5"/>
  #|      <text class="p-label" x="80" y="52" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="var(--text)">
  #|        <tspan x="80" y="52">Client</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="participant f-frontend" data-id="U">
  #|      <rect class="mask" x="196" y="24" width="96" height="48" rx="6" fill="var(--mask)"/>
  #|      <rect class="box" x="196" y="24" width="96" height="48" rx="6" fill="var(--frontend-fill)" stroke="var(--frontend-stroke)" stroke-width="1.5"/>
  #|      <text class="p-label" x="244" y="52" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="var(--text)">
  #|        <tspan x="244" y="52">User</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="participant f-backend" data-id="API">
  #|      <rect class="mask" x="340" y="24" width="96" height="48" rx="6" fill="var(--mask)"/>
  #|      <rect class="box" x="340" y="24" width="96" height="48" rx="6" fill="var(--backend-fill)" stroke="var(--backend-stroke)" stroke-width="1.5"/>
  #|      <text class="p-label" x="388" y="52" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="12" font-weight="600" fill="var(--text)">
  #|        <tspan x="388" y="52">API</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="annotations"/>
  #|</svg>

///|
let still_source_12 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1275 2454" width="1275" height="2454" role="img" data-diagram="state" data-connector-options="{&#xa;  style: Some(Rounded),&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}" id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-diagram">
  #|  <title>state-plantuml-history</title>
  #|  <desc>State structure and supplied scenarios. Guards, actions and history remain descriptive data.</desc>
  #|  <defs>
  #|    <marker id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-9 -4 L0 0 L-9 4 Z" fill="#94a3b8" stroke="#94a3b8" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-circle" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 0 A4 4 0 1 0 4 0 A4 4 0 1 0 -4 0 Z" fill="#94a3b8" stroke="#94a3b8" stroke-width="1.5"/>
  #|    </marker>
  #|    <marker id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-cross" viewBox="-10 -6 16 12" refX="0" refY="0" markerWidth="16" markerHeight="12" markerUnits="userSpaceOnUse" orient="auto-start-reverse">
  #|      <path d="M-4 -4 L4 4 M-4 4 L4 -4" fill="none" stroke="#94a3b8" stroke-width="1.5"/>
  #|    </marker>
  #|  </defs>
  #|  <rect class="bg" x="0" y="0" width="1275" height="2454" fill="#020617"/>
  #|  <g class="state-backgrounds">
  #|    <g class="state-group" data-state-id="root">
  #|      <rect class="state-bounds" x="0" y="0" width="1275" height="2454" fill="none" stroke="none"/>
  #|    </g>
  #|    <g class="state-group" data-state-id="Service" data-shape="rect" data-expanded="true" data-parent="root" data-role="Composite">
  #|      <rect class="state-bounds" x="152" y="449" width="1090.134" height="1685" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M1230.134 449 L1232.475 449.231 L1234.726 449.913 L1236.8 451.022 L1238.619 452.515 L1240.111 454.333 L1241.22 456.408 L1241.903 458.659 L1242.134 461 L1242.134 2122 L1241.903 2124.341 L1241.22 2126.592 L1240.111 2128.667 L1238.619 2130.485 L1236.8 2131.978 L1234.726 2133.087 L1232.475 2133.769 L1230.134 2134 L164 2134 L161.659 2133.769 L159.408 2133.087 L157.333 2131.978 L155.515 2130.485 L154.022 2128.667 L152.913 2126.592 L152.231 2124.341 L152 2122 L152 461 L152.231 458.659 L152.913 456.408 L154.022 454.333 L155.515 452.515 L157.333 451.022 L159.408 449.913 L161.659 449.231 L164 449 Z" fill="#020617" stroke="#94a3b8" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Service" x="196" y="474" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="700" fill="#ffffff">
  #|        <tspan x="196" y="474">Service</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-group" data-state-id="Service::region0" data-shape="rect" data-expanded="true" data-parent="Service">
  #|      <rect class="state-bounds" x="272" y="610" width="850.134" height="642" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="6 4"/>
  #|    </g>
  #|    <g class="state-group" data-state-id="Service.CONC1::region0" data-shape="rect" data-expanded="true" data-parent="Service">
  #|      <rect class="state-bounds" x="272" y="1372" width="352" height="642" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M248 1312 L1242.134 1312" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="6 4"/>
  #|    </g>
  #|  </g>
  #|  <g class="state-connections">
  #|    <g class="state-connection" data-state-id="transition/2" data-source="Service.*start*Service" data-target="Service.Worker" data-display-source="Service.*start*Service" data-display-target="Service.Worker">
  #|      <path class="state-connector" d="M404 795 L404 825 Q404 827 402 827 L402 827 Q400 827 400 829 L400 1068.734" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/2" data-connector-source="Service.*start*Service" data-connector-target="Service.Worker" data-connector-route="M404 795 L404 827 L400 827 L400 1068.734" data-connector-key="0"/>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/3" data-source="Service.Worker" data-target="Service.Worker" data-display-source="Service.Worker" data-display-target="Service.Worker">
  #|      <path class="state-connector" d="M504 1100 L528 1100 Q536 1100 536 1092 L536 1036.734 Q536 1028.734 528 1028.734 L504 1028.734 Q496 1028.734 496 1036.734 L496 1068.734" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/3" data-connector-source="Service.Worker" data-connector-target="Service.Worker" data-connector-route="M504 1100 L536 1100 L536 1028.734 L496 1028.734 L496 1068.734" data-connector-key="1"/>
  #|      <rect x="516" y="1035.367" width="40" height="21" rx="3" fill="#020617"/>
  #|      <text class="state-label" data-label-owner="transition/3" x="536" y="1050.367" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#ffffff">
  #|        <tspan x="536" y="1050.367">work</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/6" data-source="Service.CONC1.*start*CONC1" data-target="Service.CONC1.Monitor" data-display-source="Service.CONC1.*start*CONC1" data-display-target="Service.CONC1.Monitor">
  #|      <path class="state-connector" d="M404 1557 L404 1587 Q404 1589 402 1589 L402 1589 Q400 1589 400 1591 L400 1830.734" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/6" data-connector-source="Service.CONC1.*start*CONC1" data-connector-target="Service.CONC1.Monitor" data-connector-route="M404 1557 L404 1589 L400 1589 L400 1830.734" data-connector-key="2"/>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/7" data-source="Service.CONC1.Monitor" data-target="Service.CONC1.Monitor" data-display-source="Service.CONC1.Monitor" data-display-target="Service.CONC1.Monitor">
  #|      <path class="state-connector" d="M504 1862 L528 1862 Q536 1862 536 1854 L536 1798.734 Q536 1790.734 528 1790.734 L504 1790.734 Q496 1790.734 496 1798.734 L496 1830.734" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/7" data-connector-source="Service.CONC1.Monitor" data-connector-target="Service.CONC1.Monitor" data-connector-route="M504 1862 L536 1862 L536 1790.734 L496 1790.734 L496 1830.734" data-connector-key="3"/>
  #|      <rect x="512" y="1797.367" width="48" height="21" rx="3" fill="#020617"/>
  #|      <text class="state-label" data-label-owner="transition/7" x="536" y="1812.367" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#ffffff">
  #|        <tspan x="536" y="1812.367">check</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/10" data-source="*start*" data-target="Service" data-display-source="*start*" data-display-target="Service">
  #|      <path class="state-connector" d="M164 176 L164 200 Q164 208 172 208 L689.067 208 Q697.067 208 697.067 216 L697.067 449" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/10" data-connector-source="*start*" data-connector-target="Service" data-connector-route="M164 176 L164 208 L697.067 208 L697.067 449" data-connector-key="4"/>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/11" data-source="Service" data-target="Paused" data-display-source="Service" data-display-target="Paused">
  #|      <path class="state-connector" d="M697.067 2134 L697.067 2158 Q697.067 2166 689.067 2166 L168 2166 Q160 2166 160 2174 L160 2358.734" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/11" data-connector-source="Service" data-connector-target="Paused" data-connector-route="M697.067 2134 L697.067 2166 L160 2166 L160 2358.734" data-connector-key="5" mask="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-connector-underpass-5)"/>
  #|      <rect x="404.533" y="2137" width="48" height="21" rx="3" fill="#020617"/>
  #|      <text class="state-label" data-label-owner="transition/11" x="428.533" y="2152" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#ffffff">
  #|        <tspan x="428.533" y="2152">pause</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/12" data-source="Paused" data-target="Service.*historical*Service" data-display-source="Paused" data-display-target="Service.*historical*Service">
  #|      <path class="state-connector" d="M264 2390 L600 2390 Q608 2390 608 2382 L608 2171 C608 2168.5 603 2168.5 603 2166 C603 2163.5 608 2163.5 608 2161 L608 812.394 Q608 804.394 616 804.394 L640 804.394" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/12" data-connector-source="Paused" data-connector-target="Service.*historical*Service" data-connector-route="M264 2390 L608 2390 L608 804.394 L640 804.394" data-connector-key="6" mask="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-connector-underpass-6)"/>
  #|      <rect x="580" y="1568.197" width="56" height="21" rx="3" fill="#020617"/>
  #|      <text class="state-label" data-label-owner="transition/12" x="608" y="1583.197" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#ffffff">
  #|        <tspan x="608" y="1583.197">resume</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-connection" data-state-id="transition/13" data-source="Paused" data-target="Service.*deephistory*Service" data-display-source="Paused" data-display-target="Service.*deephistory*Service">
  #|      <path class="state-connector" d="M256 2358.734 L256 2326.734 Q256 2318.734 264 2318.734 L603 2318.734 C605.5 2318.734 605.5 2313.734 608 2313.734 C610.5 2313.734 610.5 2318.734 613 2318.734 L958.461 2318.734 Q966.461 2318.734 966.461 2310.734 L966.461 842.345" fill="none" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-sl-arrow)" data-connector-id="transition/13" data-connector-source="Paused" data-connector-target="Service.*deephistory*Service" data-connector-route="M256 2358.734 L256 2318.734 L966.461 2318.734 L966.461 842.345" data-connector-key="7"/>
  #|      <rect x="918.461" y="1551.54" width="96" height="21" rx="3" fill="#020617"/>
  #|      <text class="state-label" data-label-owner="transition/13" x="966.461" y="1566.54" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#ffffff">
  #|        <tspan x="966.461" y="1566.54">deep resume</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <g class="state-nodes">
  #|    <g class="state-node" data-state-id="Service.Worker" data-shape="rounded" data-expanded="true" data-parent="Service::region0" data-role="Simple">
  #|      <rect class="state-bounds" x="392" y="1068" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M492 1068 L494.341 1068.231 L496.592 1068.913 L498.667 1070.022 L500.485 1071.515 L501.978 1073.333 L503.087 1075.408 L503.769 1077.659 L504 1080 L504 1120 L503.769 1122.341 L503.087 1124.592 L501.978 1126.667 L500.485 1128.485 L498.667 1129.978 L496.592 1131.087 L494.341 1131.769 L492 1132 L404 1132 L401.659 1131.769 L399.408 1131.087 L397.333 1129.978 L395.515 1128.485 L394.022 1126.667 L392.913 1124.592 L392.231 1122.341 L392 1120 L392 1080 L392.231 1077.659 L392.913 1075.408 L394.022 1073.333 L395.515 1071.515 L397.333 1070.022 L399.408 1068.913 L401.659 1068.231 L404 1068 Z" fill="rgba(6, 78, 59, 0.4)" stroke="#34d399" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Service.Worker" x="448" y="1104.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#34d399">
  #|        <tspan x="448" y="1104.5">Worker</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="Service.*start*Service" data-shape="f-circ" data-expanded="true" data-parent="Service::region0" data-role="Initial">
  #|      <rect class="state-bounds" x="392" y="771" width="24" height="73" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M416 783 L415.942 784.176 L415.769 785.341 L415.483 786.483 L415.087 787.592 L414.583 788.657 L413.978 789.667 L413.276 790.613 L412.485 791.485 L411.613 792.276 L410.667 792.978 L409.657 793.583 L408.592 794.087 L407.483 794.483 L406.341 794.769 L405.176 794.942 L404 795 L402.824 794.942 L401.659 794.769 L400.517 794.483 L399.408 794.087 L398.343 793.583 L397.333 792.978 L396.387 792.276 L395.515 791.485 L394.724 790.613 L394.022 789.667 L393.417 788.657 L392.913 787.592 L392.517 786.483 L392.231 785.341 L392.058 784.176 L392 783 L392.058 781.824 L392.231 780.659 L392.517 779.517 L392.913 778.408 L393.417 777.343 L394.022 776.333 L394.724 775.387 L395.515 774.515 L396.387 773.724 L397.333 773.022 L398.343 772.417 L399.408 771.913 L400.517 771.517 L401.659 771.231 L402.824 771.058 L404 771 L405.176 771.058 L406.341 771.231 L407.483 771.517 L408.592 771.913 L409.657 772.417 L410.667 773.022 L411.613 773.724 L412.485 774.515 L413.276 775.387 L413.978 776.333 L414.583 777.343 L415.087 778.408 L415.483 779.517 L415.769 780.659 L415.942 781.824 L416 783 Z" fill="#fb923c" stroke="#fb923c" stroke-width="1.5"/>
  #|    </g>
  #|    <g class="state-node" data-state-id="Service.CONC1.Monitor" data-shape="rounded" data-expanded="true" data-parent="Service.CONC1::region0" data-role="Simple">
  #|      <rect class="state-bounds" x="392" y="1830" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M492 1830 L494.341 1830.231 L496.592 1830.913 L498.667 1832.022 L500.485 1833.515 L501.978 1835.333 L503.087 1837.408 L503.769 1839.659 L504 1842 L504 1882 L503.769 1884.341 L503.087 1886.592 L501.978 1888.667 L500.485 1890.485 L498.667 1891.978 L496.592 1893.087 L494.341 1893.769 L492 1894 L404 1894 L401.659 1893.769 L399.408 1893.087 L397.333 1891.978 L395.515 1890.485 L394.022 1888.667 L392.913 1886.592 L392.231 1884.341 L392 1882 L392 1842 L392.231 1839.659 L392.913 1837.408 L394.022 1835.333 L395.515 1833.515 L397.333 1832.022 L399.408 1830.913 L401.659 1830.231 L404 1830 Z" fill="rgba(6, 78, 59, 0.4)" stroke="#34d399" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Service.CONC1.Monitor" x="448" y="1866.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#34d399">
  #|        <tspan x="448" y="1866.5">Monitor</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="Service.CONC1.*start*CONC1" data-shape="f-circ" data-expanded="true" data-parent="Service.CONC1::region0" data-role="Initial">
  #|      <rect class="state-bounds" x="392" y="1533" width="24" height="73" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M416 1545 L415.942 1546.176 L415.769 1547.341 L415.483 1548.483 L415.087 1549.592 L414.583 1550.657 L413.978 1551.667 L413.276 1552.613 L412.485 1553.485 L411.613 1554.276 L410.667 1554.978 L409.657 1555.583 L408.592 1556.087 L407.483 1556.483 L406.341 1556.769 L405.176 1556.942 L404 1557 L402.824 1556.942 L401.659 1556.769 L400.517 1556.483 L399.408 1556.087 L398.343 1555.583 L397.333 1554.978 L396.387 1554.276 L395.515 1553.485 L394.724 1552.613 L394.022 1551.667 L393.417 1550.657 L392.913 1549.592 L392.517 1548.483 L392.231 1547.341 L392.058 1546.176 L392 1545 L392.058 1543.824 L392.231 1542.659 L392.517 1541.517 L392.913 1540.408 L393.417 1539.343 L394.022 1538.333 L394.724 1537.387 L395.515 1536.515 L396.387 1535.724 L397.333 1535.022 L398.343 1534.417 L399.408 1533.913 L400.517 1533.517 L401.659 1533.231 L402.824 1533.058 L404 1533 L405.176 1533.058 L406.341 1533.231 L407.483 1533.517 L408.592 1533.913 L409.657 1534.417 L410.667 1535.022 L411.613 1535.724 L412.485 1536.515 L413.276 1537.387 L413.978 1538.333 L414.583 1539.343 L415.087 1540.408 L415.483 1541.517 L415.769 1542.659 L415.942 1543.824 L416 1545 Z" fill="#fb923c" stroke="#fb923c" stroke-width="1.5"/>
  #|    </g>
  #|    <g class="state-node" data-state-id="Paused" data-shape="rounded" data-expanded="true" data-parent="root" data-role="Simple">
  #|      <rect class="state-bounds" x="152" y="2358" width="112" height="64" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M252 2358 L254.341 2358.231 L256.592 2358.913 L258.667 2360.022 L260.485 2361.515 L261.978 2363.333 L263.087 2365.408 L263.769 2367.659 L264 2370 L264 2410 L263.769 2412.341 L263.087 2414.592 L261.978 2416.667 L260.485 2418.485 L258.667 2419.978 L256.592 2421.087 L254.341 2421.769 L252 2422 L164 2422 L161.659 2421.769 L159.408 2421.087 L157.333 2419.978 L155.515 2418.485 L154.022 2416.667 L152.913 2414.592 L152.231 2412.341 L152 2410 L152 2370 L152.231 2367.659 L152.913 2365.408 L154.022 2363.333 L155.515 2361.515 L157.333 2360.022 L159.408 2358.913 L161.659 2358.231 L164 2358 Z" fill="rgba(6, 78, 59, 0.4)" stroke="#34d399" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Paused" x="208" y="2394.5" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#34d399">
  #|        <tspan x="208" y="2394.5">Paused</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="*start*" data-shape="f-circ" data-expanded="true" data-parent="root" data-role="Initial">
  #|      <rect class="state-bounds" x="152" y="152" width="24" height="73" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M176 164 L175.942 165.176 L175.769 166.341 L175.483 167.483 L175.087 168.592 L174.583 169.657 L173.978 170.667 L173.276 171.613 L172.485 172.485 L171.613 173.276 L170.667 173.978 L169.657 174.583 L168.592 175.087 L167.483 175.483 L166.341 175.769 L165.176 175.942 L164 176 L162.824 175.942 L161.659 175.769 L160.517 175.483 L159.408 175.087 L158.343 174.583 L157.333 173.978 L156.387 173.276 L155.515 172.485 L154.724 171.613 L154.022 170.667 L153.417 169.657 L152.913 168.592 L152.517 167.483 L152.231 166.341 L152.058 165.176 L152 164 L152.058 162.824 L152.231 161.659 L152.517 160.517 L152.913 159.408 L153.417 158.343 L154.022 157.333 L154.724 156.387 L155.515 155.515 L156.387 154.724 L157.333 154.022 L158.343 153.417 L159.408 152.913 L160.517 152.517 L161.659 152.231 L162.824 152.058 L164 152 L165.176 152.058 L166.341 152.231 L167.483 152.517 L168.592 152.913 L169.657 153.417 L170.667 154.022 L171.613 154.724 L172.485 155.515 L173.276 156.387 L173.978 157.333 L174.583 158.343 L175.087 159.408 L175.483 160.517 L175.769 161.659 L175.942 162.824 L176 164 Z" fill="#fb923c" stroke="#fb923c" stroke-width="1.5"/>
  #|    </g>
  #|    <g class="state-node" data-state-id="Service.*historical*Service" data-shape="circle" data-expanded="true" data-parent="Service::region0" data-role="ShallowHistory">
  #|      <rect class="state-bounds" x="640" y="771" width="66.788" height="66.788" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M706.788 804.394 L706.627 807.667 L706.147 810.909 L705.35 814.088 L704.246 817.174 L702.845 820.136 L701.16 822.947 L699.208 825.579 L697.007 828.007 L694.579 830.208 L691.947 832.16 L689.136 833.845 L686.174 835.246 L683.088 836.35 L679.909 837.147 L676.667 837.627 L673.394 837.788 L670.121 837.627 L666.879 837.147 L663.7 836.35 L660.615 835.246 L657.652 833.845 L654.841 832.16 L652.209 830.208 L649.781 828.007 L647.58 825.579 L645.628 822.947 L643.943 820.136 L642.542 817.174 L641.438 814.088 L640.642 810.909 L640.161 807.667 L640 804.394 L640.161 801.121 L640.642 797.879 L641.438 794.7 L642.542 791.615 L643.943 788.652 L645.628 785.841 L647.58 783.209 L649.781 780.781 L652.209 778.58 L654.841 776.628 L657.652 774.943 L660.615 773.542 L663.7 772.438 L666.879 771.642 L670.121 771.161 L673.394 771 L676.667 771.161 L679.909 771.642 L683.088 772.438 L686.174 773.542 L689.136 774.943 L691.947 776.628 L694.579 778.58 L697.007 780.781 L699.208 783.209 L701.16 785.841 L702.845 788.652 L704.246 791.615 L705.35 794.7 L706.147 797.879 L706.627 801.121 L706.788 804.394 Z" fill="rgba(251, 146, 60, 0.3)" stroke="#fb923c" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Service.*historical*Service" x="673.394" y="808.894" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#fb923c">
  #|        <tspan x="673.394" y="808.894">H</tspan>
  #|      </text>
  #|    </g>
  #|    <g class="state-node" data-state-id="Service.*deephistory*Service" data-shape="circle" data-expanded="true" data-parent="Service::region0" data-role="DeepHistory">
  #|      <rect class="state-bounds" x="930.788" y="771" width="71.345" height="71.345" fill="none" stroke="none" pointer-events="none" aria-hidden="true"/>
  #|      <path class="state-outline" d="M1002.134 806.673 L1001.962 810.169 L1001.448 813.632 L1000.597 817.028 L999.418 820.324 L997.921 823.489 L996.122 826.491 L994.036 829.303 L991.685 831.897 L989.091 834.248 L986.28 836.333 L983.277 838.133 L980.112 839.63 L976.816 840.809 L973.42 841.66 L969.957 842.173 L966.461 842.345 L962.964 842.173 L959.502 841.66 L956.106 840.809 L952.81 839.63 L949.645 838.133 L946.642 836.333 L943.83 834.248 L941.237 831.897 L938.886 829.303 L936.8 826.491 L935 823.489 L933.504 820.324 L932.324 817.028 L931.474 813.632 L930.96 810.169 L930.788 806.673 L930.96 803.176 L931.474 799.713 L932.324 796.317 L933.504 793.021 L935 789.857 L936.8 786.854 L938.886 784.042 L941.237 781.448 L943.83 779.097 L946.642 777.012 L949.645 775.212 L952.81 773.715 L956.106 772.536 L959.502 771.685 L962.964 771.172 L966.461 771 L969.957 771.172 L973.42 771.685 L976.816 772.536 L980.112 773.715 L983.277 775.212 L986.28 777.012 L989.091 779.097 L991.685 781.448 L994.036 784.042 L996.122 786.854 L997.921 789.857 L999.418 793.021 L1000.597 796.317 L1001.448 799.713 L1001.962 803.176 L1002.134 806.673 Z" fill="rgba(251, 146, 60, 0.3)" stroke="#fb923c" stroke-width="1.5"/>
  #|      <text class="state-label" data-label-owner="Service.*deephistory*Service" x="966.461" y="811.173" text-anchor="middle" font-family="'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace" font-size="13" font-weight="400" fill="#fb923c">
  #|        <tspan x="966.461" y="811.173">H*</tspan>
  #|      </text>
  #|    </g>
  #|  </g>
  #|  <defs>
  #|    <mask id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-connector-underpass-5" maskUnits="userSpaceOnUse" x="0" y="0" width="1275" height="2454">
  #|      <rect x="0" y="0" width="1275" height="2454" fill="white"/>
  #|      <circle cx="608" cy="2166" r="10" fill="black"/>
  #|    </mask>
  #|    <mask id="sl-u-73-74-61-74-65-2d-70-6c-61-6e-74-75-6d-6c-2d-68-69-73-74-6f-72-79-2d-64-61-72-6b-connector-underpass-6" maskUnits="userSpaceOnUse" x="0" y="0" width="1275" height="2454">
  #|      <rect x="0" y="0" width="1275" height="2454" fill="white"/>
  #|      <circle cx="608" cy="2318.734" r="10" fill="black"/>
  #|    </mask>
  #|  </defs>
  #|</svg>

///|
let still_source_13 : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" viewBox="0 0 400 200"><defs><symbol viewBox="0 0 18 18" id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52">
  #|      <defs>
  #|        <radialGradient cx="-105.006" cy="-10.409" gradientTransform="translate(117.739 19.644) scale(1.036 1.027)" gradientUnits="userSpaceOnUse" id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52-i2" r="5.954">
  #|          <stop offset="0.183" stop-color="#5ea0ef"/>
  #|          <stop offset="1" stop-color="#0078d4"/>
  #|        </radialGradient>
  #|        <clipPath id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52-i5">
  #|          <path d="M14.969,7.53A6.137,6.137,0,1,1,7.574,2.987,6.137,6.137,0,0,1,14.969,7.53Z" fill="none"/>
  #|        </clipPath>
  #|      </defs>
  #|      <path d="M2.954,5.266a.175.175,0,0,1-.176-.176h0A2.012,2.012,0,0,0,.769,3.081a.176.176,0,0,1-.176-.175h0a.176.176,0,0,1,.176-.176A2.012,2.012,0,0,0,2.778.72.175.175,0,0,1,2.954.544h0A.175.175,0,0,1,3.13.72h0A2.012,2.012,0,0,0,5.139,2.729a.175.175,0,0,1,.176.176h0a.175.175,0,0,1-.176.176h0A2.011,2.011,0,0,0,3.13,5.09.177.177,0,0,1,2.954,5.266Z" fill="#50e6ff"/>
  #|      <path d="M15.611,17.456a.141.141,0,0,1-.141-.141h0a1.609,1.609,0,0,0-1.607-1.607.141.141,0,0,1-.141-.14h0a.141.141,0,0,1,.141-.141h0a1.608,1.608,0,0,0,1.607-1.607.141.141,0,0,1,.141-.141h0a.141.141,0,0,1,.141.141h0a1.608,1.608,0,0,0,1.607,1.607.141.141,0,1,1,0,.282h0a1.609,1.609,0,0,0-1.607,1.607A.141.141,0,0,1,15.611,17.456Z" fill="#50e6ff"/>
  #|      <g>
  #|        <path d="M14.969,7.53A6.137,6.137,0,1,1,7.574,2.987,6.137,6.137,0,0,1,14.969,7.53Z" fill="url(#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52-i2)"/>
  #|        <g clip-path="url(#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52-i5)">
  #|          <path d="M5.709,13.115A1.638,1.638,0,1,0,5.714,9.84,1.307,1.307,0,0,0,5.721,9.7,1.651,1.651,0,0,0,4.06,8.064H2.832a6.251,6.251,0,0,0,1.595,5.051Z" fill="#f2f2f2"/>
  #|          <path d="M15.045,7.815c0-.015,0-.03-.007-.044a5.978,5.978,0,0,0-1.406-2.88,1.825,1.825,0,0,0-.289-.09,1.806,1.806,0,0,0-2.3,1.663,2,2,0,0,0-.2-.013,1.737,1.737,0,0,0-.581,3.374,1.451,1.451,0,0,0,.541.1h2.03A13.453,13.453,0,0,0,15.045,7.815Z" fill="#f2f2f2"/>
  #|        </g>
  #|      </g>
  #|      <path d="M17.191,3.832c-.629-1.047-2.1-1.455-4.155-1.149a14.606,14.606,0,0,0-2.082.452,6.456,6.456,0,0,1,1.528.767c.241-.053.483-.116.715-.151A7.49,7.49,0,0,1,14.3,3.662a2.188,2.188,0,0,1,1.959.725h0c.383.638.06,1.729-.886,3a16.723,16.723,0,0,1-4.749,4.051A16.758,16.758,0,0,1,4.8,13.7c-1.564.234-2.682,0-3.065-.636s-.06-1.73.886-2.995c.117-.157.146-.234.279-.392a6.252,6.252,0,0,1,.026-1.63A11.552,11.552,0,0,0,1.756,9.419C.517,11.076.181,12.566.809,13.613a3.165,3.165,0,0,0,2.9,1.249,8.434,8.434,0,0,0,1.251-.1,17.855,17.855,0,0,0,6.219-2.4,17.808,17.808,0,0,0,5.061-4.332C17.483,6.369,17.819,4.88,17.191,3.832Z" fill="#50e6ff"/>
  #|      <desc>Microsoft. MIT repository grant; provider icon terms: https://learn.microsoft.com/en-us/azure/architecture/icons/. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/Azure_Public_Service_Icons/Icons/Databases/10121-icon-service-Azure-Cosmos-DB.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol><symbol viewBox="0 0 24 24" id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49">
  #|      <defs>
  #|        <filter color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="12.76" id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49-i3" width="14.73" x="4.64" y="4.19">
  #|          <feFlood flood-color="#fff" result="bg"/>
  #|          <feBlend in="SourceGraphic" in2="bg"/>
  #|        </filter>
  #|        <mask height="12.76" id="sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49-i6" maskUnits="userSpaceOnUse" width="14.73" x="4.64" y="4.19">
  #|          <circle cx="12" cy="12.23" filter="url(#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49-i3)" r="3.58"/>
  #|        </mask>
  #|      </defs>
  #|      <g>
  #|        <circle cx="18.97" cy="8.21" fill="#669df6" r="1.72"/>
  #|        <circle cx="5.03" cy="8.21" fill="#669df6" r="1.72"/>
  #|        <circle cx="12" cy="20.28" fill="#669df6" r="1.72"/>
  #|        <g mask="url(#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49-i6)">
  #|          <rect fill="#4285f4" height="8.04" transform="matrix(0.5, -0.87, 0.87, 0.5, -4.59, 20.53)" width="1.59" x="14.69" y="10.22"/>
  #|          <rect fill="#4285f4" height="1.59" transform="translate(-5.98 6.17) rotate(-30)" width="8.04" x="4.49" y="13.45"/>
  #|          <rect fill="#4285f4" height="8.04" width="1.59" x="11.2" y="4.19"/>
  #|        </g>
  #|        <circle cx="12" cy="12.23" fill="#aecbfa" r="2.78"/>
  #|        <circle cx="5.03" cy="16.25" fill="#aecbfa" r="2.19"/>
  #|        <circle cx="18.97" cy="16.25" fill="#aecbfa" r="2.19"/>
  #|        <circle cx="12" cy="4.19" fill="#aecbfa" r="2.19"/>
  #|      </g>
  #|      <desc>Google. MIT repository grant; provider icon terms: https://cloud.google.com/icons. Source: https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/assets/google-cloud-icons/pubsub/pubsub.svg. Normalization preserves geometry, expands CSS classes and scopes IDs.
  #|MIT License
  #|
  #|Copyright (c) 2022 Peng Xiao
  #|
  #|Permission is hereby granted, free of charge, to any person obtaining a copy
  #|of this software and associated documentation files (the "Software"), to deal
  #|in the Software without restriction, including without limitation the rights
  #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|copies of the Software, and to permit persons to whom the Software is
  #|furnished to do so, subject to the following conditions:
  #|
  #|The above copyright notice and this permission notice shall be included in all
  #|copies or substantial portions of the Software.
  #|
  #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|SOFTWARE.
  #|</desc>
  #|    </symbol></defs><use href="#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-51-57-52" x="0" y="0" width="200" height="200"/><use href="#sheet-icon-p-122-101-110-117-109-108-p-97-115-115-101-116-52-49-49" x="200" y="0" width="200" height="200"/></svg>
