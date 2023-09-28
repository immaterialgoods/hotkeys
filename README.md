# Hotkeys

Hotkeys is a straightforward framework for macOS apps that want to add custom hotkey support. A few lines of code is all it takes to allow users to customize any menu command.

## Installation

Install using Swift Package Manager.

## Usage

Give an identifier to menu item you want to make hotkeyable (you can do this in IB). Create a single-column table view somewhere in your preferences. Create an instance of the HotkeysController in your app delegate (or anywhere it can persist for the life of the app) and give it access to your Main Menu and the preferences table view. That's it!

Sample code and more details to be written...

## Thanks

Two-way map code used in this project came from [Jose Canepa](https://gist.github.com/CanTheAlmighty).

## BSD License

Copyright (c) 2019-2023 Andreas Schwarz @ immaterial
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the names of Andreas Schwarz, immaterial, or Hotkeys, nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
