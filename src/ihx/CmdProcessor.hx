/*
  Copyright (c) 2009-2010, Ian Martins (ianxm@jhu.edu)

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/

package ihx;

using StringTools;
import neko.Lib;
import ihx.program.Program;

enum CmdError
{
    IncompleteStatement;
    InvalidStatement(msg :String);
}

class CmdProcessor
{
    /** accumulating command fragments */
    private var sb :StringBuf;
  
    /** hash connecting interpreter commands to the functions that implement them */
    private var commands :Hash<Dynamic>;

    /** controls temp program text */
    private var program :Program;

    /** name of new lib to include in build */
    private var newLib :String;

    public function new()
    {
        program = new Program();
        sb = new StringBuf();
        commands = new Hash<Void->String>();
        commands.set("dir", listVars);
        commands.set("lib", addRmLib);
        commands.set("libs", listLibs);
        commands.set("clear", clearVars);
        commands.set("print", printProgram);
        commands.set("help", printHelp);
        commands.set("exit", callback(neko.Sys.exit,0));
        commands.set("quit", callback(neko.Sys.exit,0));
    }

    /**
       process a line of user input
    **/
    public function process(cmd :String) :String
    {
        if( cmd.endsWith("\\") )
        {
            sb.add(cmd.substr(0, cmd.length-1));
            throw IncompleteStatement;
        }

        sb.add(cmd);
        var ret;
        try
        {
            var str = sb.toString();
            if( str.startsWith("lib ") )                    // sloppy way of passing args around
            {
                newLib = str.substr(4);
                str = "lib";
            }
            if( commands.exists(str) )                      // handle ihx commands
                ret = commands.get(str)();
            else                                            // execute a haxe statement
            {
                program.addStatement(str);
                ret = NekoEval.evaluate(program.getProgram());
                program.acceptLastCmd(true);
            }
        }
        catch (ex :String)
        {
            program.acceptLastCmd(false);
            sb = new StringBuf();
            throw InvalidStatement(ex);
        }

        sb = new StringBuf();
        return (ret==null) ? null : Std.string(ret);
    }

    /**
       return a list of all user defined variables
    **/
    private function listVars() :String
    {
        var vars = program.getVars();
        if( vars.isEmpty() )
            return "(none)";
        return wordWrap(vars.join(", "));
    }

    /**
       add a haxelib library to the compile command
    **/
    private function addRmLib() :String
    {
        NekoEval.libs.push(newLib);
        return "added: " + newLib;
    }

    /**
       list haxelib libraries
    **/
    private function listLibs() :String
    {
        return "libs: " + wordWrap(NekoEval.libs.join(", "));
    }

    /**
       reset workspace
    **/
    private function clearVars() :String
    {
        NekoEval.libs = [];
        program = new Program();
        return "cleared";
    }

    /**
       print temp program
    **/
    private function printProgram() :String
    {
        return program.getProgram();
    }

    private function wordWrap(str :String) :String
    {
        if( str.length<=80 )
            return str;
    
        var words :Array<String> = str.split(" ");
        var sb = new StringBuf();
        var ii = 0; // index of current word
        var oo = 1; // index of current output line
        while( ii<words.length )
        {
            while( ii<words.length && sb.toString().length+words[ii].length+1<80*oo )
            {
                if( ii!=0 )
                    sb.add(" ");
                sb.add(words[ii]);
                ii++;
            }
            if( ii<words.length )
            {
                sb.add("\n    ");
                oo++;
            }
        }

        return sb.toString();
    }

    private function printHelp() :String
    {
        return "ihx shell commands:\n"
            + "  dir          list all currently defined variables\n"
            + "  lib +[name]  add a haxelib library\n"
            + "  lib -[name]  remove a haxelib library\n"
            + "  libs         list haxelib libraries that have been added\n"
            + "  clear        delete all variables from the current session\n"
            + "  print        dump the temp neko program to the console\n"
            + "  help         print this message\n"
            + "  exit         close this session\n"
            + "  quit         close this session";
    }
}
